# Config resolution + branch-role resolution for the generic build/trace
# engine (tmux-build-trace-lib.sh). Bash 3.2-clean, sourced only.
#
# A repo's build/trace behavior (CI backend, job list, how each job's branch
# is computed) is declared in ".tmux-build.conf" files: plain sourced shell
# variable assignments, found by walking every directory from $HOME down to
# the target worktree path and sourcing each one found, outer to inner. A
# folder-level file (e.g. $WORKTREE_ROOT/<repo>/.tmux-build.conf) sets
# defaults for every worktree under it; sourcing order means a closer file
# overrides individual variables from a farther one just by reassigning them
# — no merge logic needed. Repos that check a ".tmux-build.conf" into their
# own tree get it automatically in every worktree, since a worktree is a real
# checkout of the repo's files.

BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

BUILD_CONFIG_VARS="BUILD_BACKEND BUILD_VPN_CHECK BUILD_CRED_NAME BUILD_JENKINS_URL BUILD_TICKET_LOOKUP BUILD_JOBS"

# Clears every BUILD_* variable a previous build_config_load call may have
# set — needed because tmux-window-picker.sh is one long-lived process that
# resolves config for a different worktree on every ctrl-g, so a stale value
# from the last worktree must not leak into the next one when it doesn't
# redefine that variable.
build_config_reset() {
  local v
  for v in $BUILD_CONFIG_VARS; do unset "$v"; done
}

# Sources every ".tmux-build.conf" found from $HOME down to worktree path $1
# (inclusive), outer to inner. Leaves BUILD_* unset (all of them, via
# build_config_reset) if $1 has no config anywhere in its ancestry.
build_config_load() {
  local target="$1" dir dirs=""

  build_config_reset

  target=$(cd "$target" 2>/dev/null && pwd) || return 1

  dir="$target"
  while :; do
    dirs="$dir
$dirs"
    [ "$dir" = "$HOME" ] && break
    [ "$dir" = "/" ] && break
    dir=$(dirname "$dir")
  done

  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    [ -f "$dir/.tmux-build.conf" ] || continue
    # shellcheck source=/dev/null
    source "$dir/.tmux-build.conf"
  done <<EOF
$dirs
EOF
}

# Ticket number + hotfix flag from branch name $1, tab-separated
# ("MOP-1234<TAB>false"). Nonzero exit and no output if $1 isn't a
# feature/hotfix branch. Only meaningful for BUILD_TICKET_LOOKUP=jira repos
# (MOP) — the jira_parent role is the only caller.
build_parse_ticket_branch() {
  case "$1" in
    feature/MOP-*) printf '%s\tfalse\n' "${1#feature/}" ;;
    hotfix/MOP-*)  printf '%s\ttrue\n'  "${1#hotfix/}"  ;;
    *) return 1 ;;
  esac
}

# uat/<parent> for ticket $1 (feature, via JIRA parent lookup), or branch $3
# itself when $2 (is_hotfix) is true. Prints the branch name, or empty +
# nonzero exit if the parent lookup fails.
build_resolve_jira_parent_branch() {
  local ticket="$1" is_hotfix="$2" branch="$3" parent
  if [ "$is_hotfix" = "true" ]; then
    printf '%s\n' "$branch"
    return 0
  fi
  parent=$(zsh -c "
    source '$BUILD_SCRIPT_DIR/ticket-lib.sh'
    source ~/.zshrc
    TICKET_DATA=\$(get_ticket_content '$ticket')
    PARENT_DATA=\$(get_ticket_parent \"\$TICKET_DATA\")
    get_from_json \"\$PARENT_DATA\" '.ticket_number'
  " 2>/dev/null)
  [ -n "$parent" ] && [ "$parent" != "null" ] || return 1
  printf 'uat/%s\n' "$parent"
}

# Resolves job spec role $1 (current|base|jira_parent) to an actual branch
# name for worktree $2, given its currently checked-out branch $3. Falls back
# to $3 itself on any resolution failure so a job spec never silently
# disappears from the trace — it just traces the wrong branch, which is
# visible in the output.
#   current     — the worktree's own checked-out branch
#   base        — the repo's default branch (main/master), via
#                 worktree-lib.sh's wt_default_base_branch (zsh)
#   jira_parent — MOP-only: the ticket's uat/<parent> branch, requires
#                 BUILD_TICKET_LOOKUP=jira in config
build_resolve_role() {
  local role="$1" wt="$2" branch="$3" parsed ticket is_hotfix result

  case "$role" in
    current)
      printf '%s\n' "$branch"
      ;;
    base)
      result=$(cd "$wt" 2>/dev/null && zsh -c "source '$BUILD_SCRIPT_DIR/worktree-lib.sh'; wt_default_base_branch" 2>/dev/null)
      printf '%s\n' "${result:-$branch}"
      ;;
    jira_parent)
      if [ "${BUILD_TICKET_LOOKUP:-}" != "jira" ]; then
        printf '%s\n' "$branch"
        return 0
      fi
      parsed=$(build_parse_ticket_branch "$branch") || { printf '%s\n' "$branch"; return 0; }
      ticket="${parsed%%$'\t'*}"
      is_hotfix="${parsed##*$'\t'}"
      result=$(build_resolve_jira_parent_branch "$ticket" "$is_hotfix" "$branch")
      printf '%s\n' "${result:-$branch}"
      ;;
    *)
      printf '%s\n' "$branch"
      return 1
      ;;
  esac
}
