# Config + branch-role resolution for the build/trace engine (tmux-build-trace-lib.sh). Bash 3.2-clean, sourced only.
#
# Build/trace behavior is declared in ".tmux-build.conf" files (plain sourced shell assignments) found by walking
# every directory from $HOME down to the target worktree path and sourcing each, outer to inner, so a closer file
# overrides a farther one just by reassigning (no merge logic). A folder-level file (e.g.
# $WORKTREE_ROOT/<repo>/.tmux-build.conf) sets defaults for every worktree under it.
#
# The walk stops *above* the target's git toplevel: a config inside a repo is repo content (a cloned repo, a
# checked-out PR branch, a file an agent wrote into its worktree), and sourcing it would run that code on every
# picker open. Put per-repo config in the folder containing the checkouts, e.g. $WORKTREE_ROOT/<repo>/.

BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

BUILD_CONFIG_VARS="BUILD_BACKEND BUILD_VPN_CHECK BUILD_CRED_NAME BUILD_JENKINS_URL BUILD_FORGEJO_URL BUILD_FORGEJO_REPO BUILD_TICKET_LOOKUP BUILD_JOBS"
WORKSPACE_CONFIG_VARS="WORKSPACE_PREVIEW_CMD WORKSPACE_SERVE_CMD WORKSPACE_SERVE_LABEL WORKSPACE_BUILD_CONF WORKSPACE_SERVE_PORT NOTE_PATH TASK_SOURCE_CMD"

# tmux-window-picker.sh is one long-lived process resolving config for a different worktree on every ctrl-g,
# so stale BUILD_* values from the previous worktree must be cleared.
build_config_reset() {
  local v
  for v in $BUILD_CONFIG_VARS; do unset "$v"; done
}

workspace_config_reset() {
  local v
  for v in $WORKSPACE_CONFIG_VARS; do unset "$v"; done
}

# Prints, outer to inner, the directories whose config files may be sourced
# for path $1: $HOME down to the directory containing $1's git toplevel (or
# $1 itself outside a repo). Nothing outside $HOME is ever included.
config_dirs() {
  local dir top dirs=""

  dir=$(cd "$1" 2>/dev/null && pwd) || return 1
  top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) && dir=$(dirname "$top")

  case "$dir/" in "$HOME"/*) ;; *) return 0 ;; esac
  while :; do
    dirs="$dir
$dirs"
    [ "$dir" = "$HOME" ] && break
    dir=$(dirname "$dir")
  done
  printf '%s' "$dirs"
}

# Sources config file $1 only if it's owned by the current user and not
# group/world-writable, so another account can't plant or edit one.
config_source_trusted() {
  local f="$1"
  [ -f "$f" ] || return 0
  if [ ! -O "$f" ] || [ -n "$(find "$f" -prune \( -perm -g+w -o -perm -o+w \) 2>/dev/null)" ]; then
    echo "Skipping untrusted config (not yours, or group/world-writable): $f" >&2
    return 0
  fi
  # shellcheck source=/dev/null
  source "$f"
}

workspace_config_load() {
  local dir

  workspace_config_reset

  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    config_source_trusted "$dir/.workspace.conf"
  done <<CONFIG_DIRS
$(config_dirs "$1")
CONFIG_DIRS
}

build_config_load() {
  local dir

  build_config_reset

  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    config_source_trusted "$dir/.tmux-build.conf"
  done <<CONFIG_DIRS
$(config_dirs "$1")
CONFIG_DIRS
}

# Ticket number + hotfix flag from branch $1, tab-separated ("MOP-1234<TAB>false"); nonzero and no output if
# $1 isn't a feature/hotfix branch. Only for BUILD_TICKET_LOOKUP=jira repos (MOP).
build_parse_ticket_branch() {
  case "$1" in
    feature/MOP-*) printf '%s\tfalse\n' "${1#feature/}" ;;
    hotfix/MOP-*)  printf '%s\ttrue\n'  "${1#hotfix/}"  ;;
    *) return 1 ;;
  esac
}

# uat/<parent> for ticket $1 (via JIRA parent lookup), or $3 itself for a hotfix; empty + nonzero if the lookup fails.
build_resolve_jira_parent_branch() {
  local ticket="$1" is_hotfix="$2" branch="$3" parent
  if [ "$is_hotfix" = "true" ]; then
    printf '%s\n' "$branch"
    return 0
  fi
  # Values go in as positional args, never spliced into the script string:
  # $ticket comes from a branch name, which may contain quotes or `;`.
  parent=$(zsh -c '
    lib_dir=$1 ticket=$2
    source "$lib_dir/ticket-lib.sh"
    source ~/.zshrc
    TICKET_DATA=$(get_ticket_content "$ticket")
    PARENT_DATA=$(get_ticket_parent "$TICKET_DATA")
    get_from_json "$PARENT_DATA" ".ticket_number"
  ' _ "$BUILD_SCRIPT_DIR" "$ticket" 2>/dev/null)
  [ -n "$parent" ] && [ "$parent" != "null" ] || return 1
  printf 'uat/%s\n' "$parent"
}

# Resolves job role $1 (current|base|jira_parent) to a branch for worktree $2 (checked out on $3). Falls back
# to $3 on any failure so a job never silently disappears from the trace; it just traces the wrong branch,
# which is visible in the output.
#   current: the worktree's own branch; base: repo default branch (wt_default_base_branch in worktree-lib.sh, zsh);
#   jira_parent: MOP-only uat/<parent> (needs BUILD_TICKET_LOOKUP=jira)
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
