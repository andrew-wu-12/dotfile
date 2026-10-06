#!/bin/bash
# Vertical window picker (prefix w): fzf popup of every tmux window across all sessions as a stack of cards.
# Modes: active (default; live windows only, no JIRA call) / all (adds a card per JIRA ticket assigned to you
# with no worktree yet; cached 5 min at /tmp/tmux-jira-picker.cache, fetched only when entered).
#
#   tab     toggle active/all
#   enter   window card: switch to it (across sessions); ticket card: create worktree + window via worktree-ticket.sh -n
#   ctrl-s  set the highlighted window's workspace as the dev-server target (needs WORKSPACE_SERVE_CMD in its .workspace.conf)
#   ctrl-r  restart whatever is served
#   ctrl-x  stop whatever is served
#   ctrl-v  view the full serve log
#   ctrl-g  popup tracing the worktree's CI jobs with a live progress bar (WORKSPACE_BUILD_CONF=1 + .tmux-build.conf)
#   ctrl-p  deploy the highlighted worktree's ticket (MOP-only): pick branch, pick job(s), trace inline
#   ctrl-n  open the workspace note in an nvim popup: NOTE_PATH/<ticket>.md when the ticket key is known, else NOTE_PATH
#   ctrl-b  open the highlighted ticket card in the JIRA browser (no-op on window cards)
#   ctrl-l  bust the ticket-status preview cache and skip the JIRA ticket-list cache on the next fetch
#   ctrl-a  actions menu: closes this popup and opens a standalone one listing the actions valid for the card,
#           by name (no tab toggle). Runs the action, then reopens the picker unless the action opened its own
#           popup (ctrl-g/ctrl-n). tmux shows one popup per client, so it can't overlay this one in place;
#           see the `--actions-popup` block below.
#   esc     cancel
#
# ctrl-s/r/x/v/p and tab loop back into a refreshed picker; enter/ctrl-g/ctrl-a/ctrl-n/esc exit (ctrl-a and
# ctrl-n hand off to their own follow-up popup instead).
# Helpers: tmux-serve-lib.sh (serve), tmux-build-trace-lib.sh (trace; also sources tmux-build-config.sh, which
# provides workspace_config_load), tmux-deploy-lib.sh (Jenkins trigger).
#
# Each card is a multi-line fzf item (--read0; fzf >= 0.44 for multi-line rendering): a bold header line
# (with any 🔴/🟢 marker), then optionally a dim ticket-title line and/or a serve status line.
# Tab-delimited fields (header is field 7, --with-nth=7):
#   {1} session name (empty on a ticket card)     {2} window id (empty on a ticket card)
#   {3} workspace path: git toplevel when WORKSPACE_SERVE_CMD or WORKSPACE_PREVIEW_CMD is set, else empty
#   {4} build path: git toplevel when WORKSPACE_BUILD_CONF=1, else empty
#   {5} preview cmd: WORKSPACE_PREVIEW_CMD (absolute path), else empty
#   {6} note path: NOTE_PATH, else empty
#   {7} display header: bold "session │ window-name", or a ticket line
#   {8} ticket key: set only on a ticket card (no worktree yet)
# ctrl-n also parses a ticket key (e.g. MOP-27970) out of {7}'s first line on window cards ({8} empty):
# tmux-dev-layout.sh names windows "{branch}(...)".
# The preview pane (right 60%) runs {5} with {3} when both are set; a placeholder for a ticket card with no
# worktree; else "(no preview configured)".

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tmux-serve-lib.sh
source "$SCRIPT_DIR/tmux-serve-lib.sh"
# shellcheck source=tmux-build-trace-lib.sh
source "$SCRIPT_DIR/tmux-build-trace-lib.sh"
# shellcheck source=tmux-deploy-lib.sh
source "$SCRIPT_DIR/tmux-deploy-lib.sh"

TAB=$(printf '\t')
BOLD=$'\033[1m'
DIM=$'\033[38;2;127;132;156m'  # catppuccin mocha "overlay1"
RESET=$'\033[0m'

mocha="--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,\
header:#f5e0dc,info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,fg+:#cdd6f4,\
prompt:#cba6f7,hl+:#f38ba8,border:#585b70"

CACHE_FILE="/tmp/tmux-jira-picker.cache"
BOARD_CACHE="/tmp/tmux-jira-picker-board.cache"
CACHE_TTL=300       # 5 minutes
BOARD_TTL=86400     # 24 hours
JIRA_BASE="https://morrisonexpress.atlassian.net"
JIRA_JQL='assignee = currentUser() AND status IN ("Backlog","Develop","In Progress","DESIGN","SA SIGNOFF","Designing","Approved","Auto Testing","Designed","DEV","DEV VERIFIED","To Do","UAT","UAT VERIFIED","Verified") ORDER BY status ASC, Rank ASC'
WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/project/worktrees}"
MOP_REPO="mop-console-monorepo"

get_jira_token() {
  local tok
  tok=$(security find-generic-password -a "$USER" -s "morrisonexpress.atlassian.net" -w 2>/dev/null)
  if [ -z "$tok" ]; then
    tok=$(zsh -c 'source ~/.zshrc >/dev/null 2>&1; printf "%s" "$JIRA_TOKEN"' 2>/dev/null)
  fi
  printf '%s' "$tok"
}

get_board_id() {
  local now mod age board_id
  if [ -f "$BOARD_CACHE" ]; then
    now=$(date +%s)
    mod=$(stat -f %m "$BOARD_CACHE" 2>/dev/null || echo 0)
    age=$(( now - mod ))
    if [ "$age" -lt "$BOARD_TTL" ]; then
      cat "$BOARD_CACHE"
      return
    fi
  fi
  local token
  token=$(get_jira_token)
  board_id=$(/usr/bin/curl -s -u "$token" -X GET \
    -H "Accept: application/json" \
    "$JIRA_BASE/rest/agile/1.0/board?projectKeyOrId=MOP&maxResults=1" \
  | jq -r '.values[0].id' 2>/dev/null)
  if [ -z "$board_id" ] || [ "$board_id" = "null" ]; then
    return 1
  fi
  printf '%s' "$board_id" > "$BOARD_CACHE"
  printf '%s' "$board_id"
}

fetch_jira_raw() {
  local token board_id
  token=$(get_jira_token)
  [ -z "$token" ] && return 1
  board_id=$(get_board_id)
  [ -z "$board_id" ] && return 1
  /usr/bin/curl -s -u "$token" -X GET \
    -H "Accept: application/json" \
    -G \
    --data-urlencode "jql=$JIRA_JQL" \
    --data-urlencode "fields=summary,status" \
    --data-urlencode "maxResults=100" \
    "$JIRA_BASE/rest/agile/1.0/board/$board_id/issue" \
  | jq -r '.issues[] | [.key, .fields.status.name, .fields.summary] | @tsv'
}

build_ticket_rows() {
  local raw now mod age
  if [ -f "$CACHE_FILE" ]; then
    now=$(date +%s)
    mod=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
    age=$(( now - mod ))
    [ "$age" -lt "$CACHE_TTL" ] && raw=$(cat "$CACHE_FILE")
  fi

  if [ -z "${raw:-}" ]; then
    raw=$(fetch_jira_raw 2>/dev/null)
    [ -z "$raw" ] && return
    printf '%s\n' "$raw" > "$CACHE_FILE"
  fi

  printf '%s\n' "$raw" | while IFS="$TAB" read -r ticket status summary; do
    [ -z "$ticket" ] && continue
    [ -d "$WORKTREE_ROOT/$MOP_REPO/$ticket" ] && continue  # already a window card
    summary=$(printf '%s' "$summary" | tr '\t' ' ')
    status_padded=$(printf '%-14s' "$status")
    header="${BOLD}${ticket}${RESET}  ${DIM}[${status_padded}]${RESET}  ${summary}"
    printf '%s\0' "${TAB}${TAB}${TAB}${TAB}${TAB}${TAB}${header}${TAB}${ticket}" >> "$list_file"
  done
}

# {5} = preview cmd, {3} = workspace path, {8} = ticket key (no-worktree card).
PREVIEW_CMD='ws={3}; p={5}; tk={8}; if [ -n "$tk" ] && [ -z "$ws" ]; then printf "(no worktree yet — press enter to create)\n"; elif [ -n "$p" ] && [ -n "$ws" ]; then "$p" "$ws"; else printf "(no preview configured)\n"; fi'

RELOAD_BIND="ctrl-l:execute-silent(rm -f $CACHE_FILE)+execute-silent(~/bin/tmux-ticket-status.sh --reload {3} 2>/dev/null)+refresh-preview"

CTRL_B_BIND="ctrl-b:execute-silent(t={8}; [ -n \"\$t\" ] && open \"$JIRA_BASE/browse/\$t\")"

SERVE_INFO=$(serve_find_window)
SERVE_WIN=$(printf '%s' "$SERVE_INFO" | cut -d' ' -f2)
SERVE_PANE=$(printf '%s' "$SERVE_INFO" | cut -d' ' -f3)

list_file=$(mktemp)
trap 'rm -f "$list_file"' EXIT

serve_switch_to() {  # $1 = workspace path
  local target="$1"
  workspace_config_load "$target"
  local serve_cmd="${WORKSPACE_SERVE_CMD:-yarn serve}"
  local serve_label="${WORKSPACE_SERVE_LABEL:-$(basename "$target")}"
  local serve_port="${WORKSPACE_SERVE_PORT:-}"

  SERVE_INFO=$(serve_ensure_window "$serve_label")
  SERVE_WIN=$(printf '%s' "$SERVE_INFO" | cut -d' ' -f2)
  SERVE_PANE=$(printf '%s' "$SERVE_INFO" | cut -d' ' -f3)

  tmux send-keys -t "$SERVE_PANE" C-c
  local cmd
  for _ in $(seq 1 20); do
    cmd=$(tmux display-message -p -t "$SERVE_PANE" '#{pane_current_command}' 2>/dev/null)
    case "$cmd" in zsh|bash|sh) break ;; esac
    sleep 0.5
  done
  cmd=$(tmux display-message -p -t "$SERVE_PANE" '#{pane_current_command}' 2>/dev/null)
  case "$cmd" in
    zsh|bash|sh) : ;;
    *) tmux send-keys -t "$SERVE_PANE" C-c ;;
  esac

  tmux clear-history -t "$SERVE_PANE"
  tmux send-keys -t "$SERVE_PANE" -l 'clear' \; send-keys -t "$SERVE_PANE" Enter
  tmux send-keys -t "$SERVE_PANE" "$(printf 'cd %q' "$target") && $serve_cmd" Enter
  tmux set-option -w -t "$SERVE_WIN" @serve_target "$target"
  tmux set-option -w -t "$SERVE_WIN" @serve_port "$serve_port"

  sleep 1
}

serve_stop_current() {
  tmux send-keys -t "$SERVE_PANE" C-c
  tmux set-option -w -t "$SERVE_WIN" -u @serve_target
  tmux set-option -w -t "$SERVE_WIN" -u @serve_port
  sleep 1
}

# ctrl-p: deploy (MOP-only). Gated on a resolved .tmux-build.conf (trace_prepare, as ctrl-g), VPN when
# BUILD_VPN_CHECK=1, and a MOP feature/hotfix branch. Step 1 picks the branch (ticket's own or uat/<parent>);
# step 2 picks job(s): dev fires _feature, uat fires _epic_or_hotfix, one fires both _dev and _uat, all
# against step 1's branch.
deploy_run() {
  local wt="$1" branch parsed ticket is_hotfix uat_branch
  local branch_opts branch_choice job_choice
  local specs=()

  trace_prepare "$wt" || { sleep 1; return; }
  if [ "$BUILD_BACKEND" != "jenkins" ]; then
    echo "Deploy is Jenkins-only (BUILD_BACKEND=$BUILD_BACKEND)."; sleep 1; return
  fi

  if [ "${BUILD_VPN_CHECK:-0}" = "1" ] && ! trace_vpn_connected; then
    echo "VPN required to trigger deploy."; sleep 1; return
  fi

  branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)
  parsed=$(build_parse_ticket_branch "$branch") || {
    echo "Not on a MOP feature/hotfix branch (current: $branch)."; sleep 1; return
  }
  ticket="${parsed%%$'\t'*}"
  is_hotfix="${parsed##*$'\t'}"

  uat_branch=$(build_resolve_jira_parent_branch "$ticket" "$is_hotfix" "$branch")
  [ -n "$uat_branch" ] || uat_branch="$branch"

  branch_opts="$branch\n"
  [ "$uat_branch" != "$branch" ] && branch_opts="$branch\n$uat_branch"

  branch_choice=$(printf "$branch_opts" | fzf \
    --layout=reverse --border=rounded --height=~100% \
    --header="(1/2) Select Target Branch" --prompt='branch ❯ ' \
    --pointer='▶' \
    $mocha) || return
  [ -z "$branch_choice" ] && return

  job_choice=$(printf 'dev\nuat\none\n' | fzf \
    --layout=reverse --border=rounded --height=~100% \
    --header="(2/2) Select Target Environment" --prompt='job ❯ ' \
    --pointer='▶' \
    $mocha) || return
  [ -z "$job_choice" ] && return

  TRACE_NOTIFY_SUBTITLE="$ticket · $branch_choice"
  case "$job_choice" in
    dev)
      deploy_trigger_job mop_console_monorepo_feature BRANCH "$branch_choice" \
        && specs+=("$(trace_job_spec mop_console_monorepo_feature "$branch_choice")")
      ;;
    uat)
      deploy_trigger_job mop_console_monorepo_epic_or_hotfix BRANCH "$branch_choice" \
        && specs+=("$(trace_job_spec mop_console_monorepo_epic_or_hotfix "$branch_choice")")
      ;;
    one)
      deploy_trigger_job mop_console_monorepo_dev BRANCH "$branch_choice" \
        && specs+=("$(trace_job_spec mop_console_monorepo_dev "$branch_choice")")
      deploy_trigger_job mop_console_monorepo_uat BRANCH "$branch_choice" \
        && specs+=("$(trace_job_spec mop_console_monorepo_uat "$branch_choice")")
      ;;
    *)
      return
      ;;
  esac

  if [ "${#specs[@]}" -eq 0 ]; then
    echo "Deploy trigger failed."; sleep 1; return
  fi

  trace_run "${specs[@]}"
  if [ $? -eq 1 ]; then
    echo "No build showed up in Jenkins for the triggered job(s) — check Jenkins directly."
  fi

  echo ""
  echo "Press enter to return to the picker..."
  read -r _
}

# ctrl-a never runs the actions menu inline: tmux shows one popup per client and this picker is already in
# one, so the menu opens as its own standalone popup (same close-then-relaunch trick as ctrl-g/ctrl-n) via
# `--actions-popup <ctx...>` (block further down). The functions below are the per-action bodies shared by the
# main loop's hotkeys and that popup (which has no fzf loop of its own). They act on the sess/winid/ws_path/
# build_wt_path/note_path/ticket/ticket8/CUR_TARGET/SERVE_WIN/SERVE_PANE globals (parsed from $first_line, or
# passed as positional args in the popup). Return 1 on a precondition failure (already printed + slept), else
# the action's exit status. ctrl-g/ctrl-n schedule their own follow-up popup on success, so callers must not
# also reopen the picker.

action_serve() {
  if [ -z "$ws_path" ]; then echo "No WORKSPACE_SERVE_CMD configured for this window."; sleep 1; return 1; fi
  if [ "$ws_path" = "$CUR_TARGET" ]; then echo "Already serving this workspace."; sleep 1; return 1; fi
  serve_switch_to "$ws_path"
}

action_restart() {
  if [ -z "$CUR_TARGET" ]; then echo "Nothing is being served."; sleep 1; return 1; fi
  serve_switch_to "$CUR_TARGET"
}

action_stop() {
  if [ -z "$CUR_TARGET" ]; then echo "Nothing is being served."; sleep 1; return 1; fi
  serve_stop_current
}

action_viewlog() {
  if [ -z "$CUR_TARGET" ]; then echo "Nothing is being served."; sleep 1; return 1; fi
  tmux capture-pane -p -t "$SERVE_PANE" -S -500 | less -R +G
}

action_trace() {
  if [ -z "$build_wt_path" ]; then
    echo "No WORKSPACE_BUILD_CONF=1 configured for this window."; sleep 1; return 1
  fi
  trace_open_popup "$build_wt_path" || { sleep 1; return 1; }
}

action_deploy() {
  if [ -z "$ws_path" ]; then echo "Not a workspace window."; sleep 1; return 1; fi
  deploy_run "$ws_path"
}

action_notes() {
  if [ -z "$note_path" ]; then
    echo "No NOTE_PATH configured for this workspace."; sleep 1; return 1
  fi
  local full_note_path="$note_path"
  [ -n "$ticket" ] && full_note_path="$note_path/$ticket.md"
  # One popup per client and this picker is already in one, so schedule the nvim popup (as trace_open_popup
  # does) to open after this one closes.
  local popup_cmd
  popup_cmd=$(printf 'sleep 0.3 && tmux display-popup -E -w 90%% -h 80%% %s || true' "$(printf 'nvim %q' "$full_note_path")")
  tmux run-shell -b "$popup_cmd"
}

action_browser() {
  if [ -z "$ticket8" ]; then echo "No ticket associated with this card."; sleep 1; return 1; fi
  open "$JIRA_BASE/browse/$ticket8"
}

action_reload_cache() {
  rm -f "$CACHE_FILE"
  ~/bin/tmux-ticket-status.sh --reload "$ws_path" 2>/dev/null
}

worktree_root_for_window() {
  local pane_path root
  [ -n "$winid" ] || return 1
  pane_path=$(tmux display-message -p -t "$winid" '#{pane_current_path}' 2>/dev/null) || return 1
  root=$(git -C "$pane_path" rev-parse --show-toplevel 2>/dev/null) || return 1
  [ -f "$root/.git" ] || return 1
  printf '%s' "$root"
}

action_close_worktree() {
  local root branch answer out status
  root=$(worktree_root_for_window) || { echo "Not a linked worktree."; sleep 1; return 1; }
  branch=$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null)
  printf 'Close %s worktree? [y/N] ' "$branch"
  read -r answer
  case "$answer" in
    y|Y) ;;
    *) return 1 ;;
  esac
  out=$(mktemp)
  (cd "$root" && zsh ~/bin/worktree-done.sh) 2>&1 | tee "$out"
  status=${PIPESTATUS[0]}
  if [ "$status" -ne 0 ] || grep -q 'not deleted (unmerged)' "$out"; then
    printf '\nPress any key to continue...'
    read -r -n 1 -s
  fi
  rm -f "$out"
  return "$status"
}

strip_ansi() {
  sed -e $'s/\x1b\[[0-9;]*m//g'
}

# Quotes argv for embedding in a `tmux run-shell`/display-popup command string (each arg prefixed with a space).
quote_args() {
  local out="" a
  for a in "$@"; do
    out="$out $(printf '%q' "$a")"
  done
  printf '%s' "$out"
}

# ctrl-a submenu: only actions valid for the highlighted card, labeled by name and headed by its display name;
# excludes the tab toggle (a mode switch, not a per-card action). Echoes the chosen hotkey, nothing on cancel.
show_actions_menu_standalone() {
  local label="$1" menu_file choice
  menu_file=$(mktemp)

  {
    if [ -n "$ws_path" ] && [ "$ws_path" != "$CUR_TARGET" ]; then
      printf 'ctrl-s\tServe this workspace\n'
    fi
    if [ -n "$CUR_TARGET" ]; then
      printf 'ctrl-r\tServe: Restart\n'
      printf 'ctrl-x\tServe: Stop\n'
      printf 'ctrl-v\tServe: View\n'
    fi
    if [ -n "$build_wt_path" ]; then
      printf 'ctrl-g\tBuild: Trace\n'
    fi
    if [ -n "$ws_path" ]; then
      printf 'ctrl-p\tBuild: Deploy\n'
    fi
    if [ -n "$note_path" ]; then
      printf 'ctrl-n\tNotes: Open\n'
    fi
    if [ -n "$ticket8" ]; then
      printf 'ctrl-b\tOpen ticket in browser\n'
    fi
    printf 'ctrl-l\tReload cache\n'
    if worktree_root_for_window >/dev/null; then
      printf 'wt-close\tWorktree: Close\n'
    fi
  } > "$menu_file"

  choice=$(fzf < "$menu_file" \
    --delimiter="$TAB" --with-nth=2 \
    --layout=reverse --border=rounded \
    --header="$label" --header-first --prompt='action ❯ ' \
    --pointer='▶' \
    $mocha)
  rm -f "$menu_file"
  [ -z "$choice" ] && return 1
  printf '%s' "${choice%%$TAB*}"
}

# Card list. Written to a file, not a variable: bash silently drops NUL bytes from variables, which would
# collapse every card into one unselectable blob. workspace_config_load walks up from each pane path to $HOME
# for a .workspace.conf (a few stats per pane; works for worktrees and plain checkouts).
build_window_rows() {
  # \x1f (unit separator), not a tab: IFS=<tab> is still an "IFS whitespace"
  # character to read/word-splitting, which squeezes runs of it and drops
  # empty fields — fatal here since @ticket_title is legitimately empty on
  # any non-mwt window (main checkout, `wt` worktrees) and isn't last in the
  # list, so a squeeze shifts panepath into title's slot and leaves panepath
  # itself empty, same failure tmux-ticket-status.sh's cache row hit already
  # works around.
  local US=$'\x1f'
  tmux list-windows -a \
    -F "#{session_name}${US}#{window_id}${US}#{session_name} │ #{window_name}${US}#{@ticket_title}${US}#{@workspace_path}${US}#{pane_current_path}" \
    | while IFS="$US" read -r sess winid header title wspath panepath; do
        case "$header" in
          *" │ serve("*|*" serve("*) continue ;;
        esac

        ws_path=""
        build_wt_path=""
        preview_cmd=""
        note_path=""

        # Prefer the window's fixed @workspace_path (set by tmux-dev-layout.sh) over the live pane path: the
        # pane's cwd drifts when a shell/agent cd's, falsely matching this window to whichever worktree is
        # being served. Falls back to panepath for untagged windows.
        config_path="${wspath:-$panepath}"

        workspace_config_load "$config_path"

        if [ -n "${WORKSPACE_SERVE_CMD:-}" ] || [ -n "${WORKSPACE_PREVIEW_CMD:-}" ] || [ "${WORKSPACE_BUILD_CONF:-}" = "1" ]; then
          top=$(git -C "$config_path" rev-parse --show-toplevel 2>/dev/null)
          if [ -n "$top" ]; then
            { [ -n "${WORKSPACE_SERVE_CMD:-}" ] || [ -n "${WORKSPACE_PREVIEW_CMD:-}" ]; } && ws_path="$top"
            [ "${WORKSPACE_BUILD_CONF:-}" = "1" ] && build_wt_path="$top"
          fi
        fi
        preview_cmd="${WORKSPACE_PREVIEW_CMD:-}"
        note_path="${NOTE_PATH:-}"

        record="${sess}${TAB}${winid}${TAB}${ws_path}${TAB}${build_wt_path}${TAB}${preview_cmd}${TAB}${note_path}${TAB}${BOLD}${header}${RESET}"
        [ -n "$title" ] && record="${record}
  ${DIM}${title}${RESET}"

        if [ -n "$ws_path" ] && [ -n "${WORKSPACE_SERVE_CMD:-}" ]; then
          if [ "$ws_path" = "$CUR_TARGET" ]; then
            if [ -n "$CUR_PORT" ]; then
              status_line=$(printf '%s %s   http://localhost:%s' "$(serve_status_dot)" "$STATUS" "$CUR_PORT")
            else
              status_line=$(printf '%s %s' "$(serve_status_dot)" "$STATUS")
            fi
            record="${record}
  ${status_line}"
            if [ "$STATUS" = "error" ] && [ -n "$ERR_DETAIL" ]; then
              while IFS= read -r errline; do
                [ -n "$errline" ] && record="${record}
  ${DIM}${errline}${RESET}"
              done <<EOF
$ERR_DETAIL
EOF
            fi
          else
            record="${record}
  ${DIM}⚡ servable — ctrl-s to serve${RESET}"
          fi
        fi

        printf '%s\0' "${record}${TAB}" >> "$list_file"
      done
}

build_list() {
  serve_compute_status
  CUR_TARGET=$(serve_current_target "$SERVE_WIN")
  CUR_PORT=$([ -n "$SERVE_WIN" ] && tmux show-option -w -t "$SERVE_WIN" -v @serve_port 2>/dev/null || true)
  : > "$list_file"

  build_window_rows
  [ "$MODE" = "all" ] && build_ticket_rows
}

# --actions-popup: standalone popup for ctrl-a, never invoked by hand. ctrl-a closes the current popup and
# schedules `... --actions-popup <ctx...>` with the highlighted card's context as positional args (tmux shows
# one popup per client). Runs the chosen action, then reopens the picker unless the action scheduled its own
# popup (ctrl-g/ctrl-n), which a reopen here would race.
if [ "${1:-}" = "--actions-popup" ]; then
  shift
  sess="$1"; winid="$2"; ws_path="$3"; build_wt_path="$4"
  note_path="$5"; ticket="$6"; ticket8="$7"; CUR_TARGET="$8"; label="${9:-}"

  action=$(show_actions_menu_standalone "$label")

  reopen=1
  if [ -n "$action" ]; then
    case "$action" in
      ctrl-s) action_serve ;;
      ctrl-r) action_restart ;;
      ctrl-x) action_stop ;;
      ctrl-v) action_viewlog ;;
      ctrl-g) action_trace && reopen=0 ;;
      ctrl-p) action_deploy ;;
      ctrl-n) action_notes && reopen=0 ;;
      ctrl-b) action_browser ;;
      ctrl-l) action_reload_cache ;;
      wt-close) action_close_worktree ;;
    esac
  fi

  if [ "$reopen" = 1 ]; then
    reopen_cmd=$(printf 'sleep 0.3 && tmux display-popup -E -w 90%% -h 80%% %s || true' "$(printf '%q' "$SCRIPT_DIR/tmux-window-picker.sh")")
    tmux run-shell -b "$reopen_cmd"
  fi
  exit 0
fi

MODE="active"
while true; do
  build_list
  [ -s "$list_file" ] || exit 0

  if [ "$MODE" = "active" ]; then
    HEADER=$(printf 'ctrl-a:actions menu  tab:all tickets  ctrl-s:serve  ctrl-r:restart  ctrl-x:stop  ctrl-g:trace build\nctrl-p:deploy  ctrl-v:view log  ctrl-n:notes  ctrl-l:reload preview')
    PROMPT='window ❯ '
  else
    HEADER=$(printf 'ctrl-a:actions menu  tab:active only  ctrl-b:browser  ctrl-l:reload tickets  ctrl-s:serve  ctrl-r:restart\nctrl-x:stop  ctrl-g:trace build  ctrl-p:deploy  ctrl-v:view log  ctrl-n:notes')
    PROMPT='all ❯ '
  fi

  result=$(fzf \
    --read0 \
    --ansi \
    --gap=1 \
    --delimiter="$TAB" \
    --with-nth=7 \
    --layout=reverse \
    --border=rounded \
    --margin=0 \
    --header="$HEADER" \
    --header-first \
    --prompt="$PROMPT" \
    --pointer='▶' \
    --expect=ctrl-s,ctrl-r,ctrl-x,ctrl-v,ctrl-g,ctrl-p,ctrl-n,ctrl-a,tab \
    --bind="$RELOAD_BIND" \
    --bind="$CTRL_B_BIND" \
    --preview="$PREVIEW_CMD" \
    --preview-window=right:60%:wrap \
    $mocha < "$list_file") || exit 0

  [ -z "$result" ] && exit 0

  KEY=$(printf '%s\n' "$result" | sed -n '1p')
  first_line=$(printf '%s\n' "$result" | sed -n '2p')
  sess=$(printf '%s' "$first_line" | cut -d"$TAB" -f1)
  winid=$(printf '%s' "$first_line" | cut -d"$TAB" -f2)
  ws_path=$(printf '%s' "$first_line" | cut -d"$TAB" -f3)
  build_wt_path=$(printf '%s' "$first_line" | cut -d"$TAB" -f4)
  note_path=$(printf '%s' "$first_line" | cut -d"$TAB" -f6)
  ticket8=$(printf '%s' "$first_line" | cut -d"$TAB" -f8)
  ticket="$ticket8"
  [ -z "$ticket" ] && ticket=$(printf '%s' "$first_line" | grep -oE '[A-Z]+-[0-9]+' | head -1)

  case "$KEY" in
    tab)
      [ "$MODE" = "active" ] && MODE="all" || MODE="active"
      continue
      ;;
    ctrl-a)
      label=$(printf '%s' "$first_line" | cut -d"$TAB" -f7 | strip_ansi)
      popup_cmd=$(printf 'sleep 0.3 && tmux display-popup -E -w 50%% -h 40%% %s%s || true' \
        "$(printf '%q' "$SCRIPT_DIR/tmux-window-picker.sh")" \
        "$(quote_args --actions-popup "$sess" "$winid" "$ws_path" "$build_wt_path" "$note_path" "$ticket" "$ticket8" "$CUR_TARGET" "$label")")
      tmux run-shell -b "$popup_cmd"
      exit 0
      ;;
    ctrl-s) action_serve; continue ;;
    ctrl-r) action_restart; continue ;;
    ctrl-x) action_stop; continue ;;
    ctrl-v) action_viewlog; continue ;;
    ctrl-g)
      if action_trace; then exit 0; else continue; fi
      ;;
    ctrl-p) action_deploy; continue ;;
    ctrl-n)
      if action_notes; then exit 0; else continue; fi
      ;;
  esac

  if [ -n "$ticket" ] && [ -z "$winid" ]; then
    zsh ~/bin/worktree-ticket.sh -n "$ticket"
    exit 0
  fi

  [ -z "$winid" ] && continue
  tmux switch-client -t "$sess"
  tmux select-window -t "$winid"
  exit 0
done
