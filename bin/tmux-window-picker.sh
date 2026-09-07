#!/bin/bash
# Vertical window picker: an fzf popup listing every tmux window across all
# sessions as a vertical stack of cards. Absorbs the old tmux-jira-picker.sh
# (formerly `prefix j`) as a second, toggleable row set.
#
# Two modes:
#   active  (default) Today's window list only — one card per live tmux
#           window across all sessions. No JIRA call.
#   all     Adds a card per JIRA ticket assigned to you that has no worktree
#           yet (tickets that already have a worktree show up as window
#           cards above, in "active"). Cached 5 min at
#           /tmp/tmux-jira-picker.cache; only fetched when this mode is
#           entered, never on plain open.
#
#   tab     Toggle active/all.
#   enter   On a window card: switch to it (across sessions) and exit.
#           On a ticket card (no worktree yet): create the worktree + window
#           via worktree-ticket.sh -n and exit.
#
#   ctrl-s  Set the highlighted window's workspace as the dev-server target.
#           Requires WORKSPACE_SERVE_CMD in the window's .workspace.conf.
#   ctrl-r  Restart whatever is currently served.
#   ctrl-x  Stop whatever is currently served.
#   ctrl-v  View the full serve log.
#
#   ctrl-g  Open a popup tracing this worktree's configured CI jobs with a
#           live progress bar (any workspace with WORKSPACE_BUILD_CONF=1 and
#           a .tmux-build.conf).
#
#   ctrl-p  Deploy the highlighted worktree's ticket (MOP-only): pick a
#           branch, then pick job(s) to fire, then trace them inline.
#
#   ctrl-n  Open NOTE_PATH for this workspace in an nvim popup.
#
#   ctrl-b  Open the highlighted ticket in the JIRA browser (ticket cards
#           only; no-op on window cards).
#   ctrl-l  Bust the ticket-status preview cache for the highlighted card,
#           and force the next JIRA ticket-list fetch to skip its cache.
#   esc     Cancel.
#
# ctrl-s/ctrl-r/ctrl-x/ctrl-v/ctrl-p/ctrl-n/tab loop back into a refreshed
# picker; enter/ctrl-g/esc are the only ways out. Shared serve helpers live
# in tmux-serve-lib.sh; shared build-trace helpers live in
# tmux-build-trace-lib.sh (which also sources tmux-build-config.sh, making
# workspace_config_load available here); shared Jenkins-trigger helpers live
# in tmux-deploy-lib.sh.
#
# Each card is a multi-line fzf item (fzf --read0, fzf >= 0.44 required for
# multi-line item rendering): a bold header line carrying any 🔴/🟢 marker,
# then optionally a dim ticket-title line and/or a serve status/marker line.
# Tab-delimited fields (header is field 7, displayed via --with-nth=7):
#   {1} session name          — empty on a ticket card
#   {2} window id             — empty on a ticket card
#   {3} workspace path        — git toplevel when WORKSPACE_SERVE_CMD or
#                                WORKSPACE_PREVIEW_CMD is set; empty otherwise
#   {4} build path            — git toplevel when WORKSPACE_BUILD_CONF=1; empty otherwise
#   {5} preview cmd           — WORKSPACE_PREVIEW_CMD (absolute path); empty if none
#   {6} note path              — NOTE_PATH; empty if none
#   {7} display header         — bold "session │ window-name", or a ticket line
#   {8} ticket key              — set only on a ticket card (no worktree yet)
#
# The preview pane (right 60%) calls {5} with {3} as argument when both are
# set; shows a placeholder for a ticket card with no worktree; else shows
# "(no preview configured)".

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tmux-serve-lib.sh
source "$SCRIPT_DIR/tmux-serve-lib.sh"
# shellcheck source=tmux-build-trace-lib.sh
source "$SCRIPT_DIR/tmux-build-trace-lib.sh"
# shellcheck source=tmux-deploy-lib.sh
source "$SCRIPT_DIR/tmux-deploy-lib.sh"
# tmux-build-trace-lib.sh sources tmux-build-config.sh, giving us
# workspace_config_load / workspace_config_reset here.

TAB=$(printf '\t')
BOLD=$'\033[1m'
DIM=$'\033[38;2;127;132;156m'  # catppuccin mocha "overlay1"
RESET=$'\033[0m'

mocha="--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,\
header:#f5e0dc,info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,fg+:#cdd6f4,\
prompt:#cba6f7,hl+:#f38ba8,border:#585b70"

# --- JIRA ticket list (absorbed from tmux-jira-picker.sh) -----------------

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

# Resolve the numeric board ID for the MOP project; cache for 24h.
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

# Appends one record per ticket assigned to the user that has no worktree
# yet (tickets that already have one show up as window cards instead).
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

# ctrl-l busts the ticket-status preview cache and the JIRA ticket-list cache.
RELOAD_BIND="ctrl-l:execute-silent(rm -f $CACHE_FILE)+execute-silent(~/bin/tmux-ticket-status.sh --reload {3} 2>/dev/null)+refresh-preview"

# ctrl-b opens the highlighted ticket card in the JIRA browser; no-op on a
# window card (empty {8}).
CTRL_B_BIND="ctrl-b:execute-silent(t={8}; [ -n \"\$t\" ] && open \"$JIRA_BASE/browse/\$t\")"

SERVE_INFO=$(serve_find_window)
SERVE_WIN=$(printf '%s' "$SERVE_INFO" | cut -d' ' -f2)
SERVE_PANE=$(printf '%s' "$SERVE_INFO" | cut -d' ' -f3)

list_file=$(mktemp)
trap 'rm -f "$list_file"' EXIT

# --- start/stop actions on the hidden serve window ---------------------

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
  tmux send-keys -t "$SERVE_PANE" "cd '$target' && $serve_cmd" Enter
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

# --- ctrl-p: deploy (MOP-only) -------------------------------------------
#
# Gated on VPN, a resolved .tmux-build.conf, and a MOP feature/hotfix branch.
# Step 1 picks the branch (ticket's own, or uat/<parent>). Step 2 picks the
# job(s): dev fires _feature, uat fires _epic_or_hotfix, one fires both
# _dev and _uat — all against the branch chosen in step 1.
deploy_run() {
  local wt="$1" branch parsed ticket is_hotfix uat_branch
  local branch_opts branch_choice job_choice
  local specs=()

  build_config_load "$wt"
  if [ -z "${BUILD_BACKEND:-}" ]; then
    echo "No .tmux-build.conf found for this worktree."; sleep 1; return
  fi

  if ! trace_vpn_connected; then
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

  branch_opts="ticket branch: $branch"
  [ "$uat_branch" != "$branch" ] && branch_opts="$branch_opts
uat branch: $uat_branch"

  branch_choice=$(printf '%s\n' "$branch_opts" | fzf \
    --layout=reverse --border=rounded --height=~6 \
    --header="Deploy $ticket — pick a branch (1/2 or ↑↓+Enter)" --prompt='branch ❯ ' \
    --pointer='▶' \
    --bind='1:pos(1)+accept,2:pos(2)+accept' \
    $mocha) || return
  [ -z "$branch_choice" ] && return
  branch_choice="${branch_choice#ticket branch: }"
  branch_choice="${branch_choice#uat branch: }"

  job_choice=$(printf 'dev\nuat\none\n' | fzf \
    --layout=reverse --border=rounded --height=~6 \
    --header="Deploy $branch_choice — d/u/o to pick, or ↑↓+Enter" --prompt='job ❯ ' \
    --pointer='▶' \
    --bind='d:pos(1)+accept,u:pos(2)+accept,o:pos(3)+accept' \
    $mocha) || return
  [ -z "$job_choice" ] && return

  JENKINS_TOKEN=$(zsh -c 'source ~/.zshrc >/dev/null 2>&1; printf "%s" "$JENKINS_TOKEN"' 2>/dev/null)
  if [ -z "$JENKINS_TOKEN" ]; then
    echo "Error: JENKINS_TOKEN is not set."; sleep 1; return
  fi

  TRACE_NOTIFY_SUBTITLE="$ticket · $branch_choice"
  case "$job_choice" in
    dev)
      deploy_trigger_job mop_console_monorepo_feature BRANCH "$branch_choice" \
        && specs+=("FEAT|mop_console_monorepo_feature|$branch_choice|feature build")
      ;;
    uat)
      deploy_trigger_job mop_console_monorepo_epic_or_hotfix BRANCH "$branch_choice" \
        && specs+=("EPIC|mop_console_monorepo_epic_or_hotfix|$branch_choice|epic/hotfix build")
      ;;
    one)
      deploy_trigger_job mop_console_monorepo_dev BRANCH "$branch_choice" \
        && specs+=("DEV|mop_console_monorepo_dev|$branch_choice|dev build")
      deploy_trigger_job mop_console_monorepo_uat BRANCH "$branch_choice" \
        && specs+=("UAT|mop_console_monorepo_uat|$branch_choice|uat build")
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

# --- card list -----------------------------------------------------------
#
# Written to a file, not a variable: bash silently drops embedded NUL bytes
# from variables, which would collapse every card into one unselectable blob.
#
# For every pane, workspace_config_load walks up from the pane path to $HOME
# looking for a .workspace.conf. This is cheap (a few stat calls per pane) and
# works for worktrees and plain checkouts alike.
build_window_rows() {
  tmux list-windows -a \
    -F "#{session_name}${TAB}#{window_id}${TAB}#{session_name} │ #{window_name}${TAB}#{@ticket_title}${TAB}#{pane_current_path}" \
    | while IFS="$TAB" read -r sess winid header title panepath; do
        # hide the hidden serve window (pattern-match serve(*) with optional marker prefix)
        case "$header" in
          *" │ serve("*|*" serve("*) continue ;;
        esac

        ws_path=""
        build_wt_path=""
        preview_cmd=""
        note_path=""

        workspace_config_load "$panepath"

        if [ -n "${WORKSPACE_SERVE_CMD:-}" ] || [ -n "${WORKSPACE_PREVIEW_CMD:-}" ] || [ "${WORKSPACE_BUILD_CONF:-}" = "1" ]; then
          top=$(git -C "$panepath" rev-parse --show-toplevel 2>/dev/null)
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

# --- main loop -------------------------------------------------------------
#
# enter/ctrl-g/esc exit; ctrl-s/ctrl-r/ctrl-x/ctrl-v/ctrl-p/ctrl-n/tab act
# and loop back into a refreshed picker.
MODE="active"
while true; do
  build_list
  [ -s "$list_file" ] || exit 0

  if [ "$MODE" = "active" ]; then
    HEADER=$(printf 'tab:all tickets  ctrl-s:serve  ctrl-r:restart  ctrl-x:stop  ctrl-g:trace build  ctrl-p:deploy\nctrl-v:view log  ctrl-n:notes  ctrl-l:reload preview')
    PROMPT='window ❯ '
  else
    HEADER=$(printf 'tab:active only  ctrl-b:browser  ctrl-l:reload tickets  ctrl-s:serve  ctrl-r:restart  ctrl-x:stop\nctrl-g:trace build  ctrl-p:deploy  ctrl-v:view log  ctrl-n:notes')
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
    --expect=ctrl-s,ctrl-r,ctrl-x,ctrl-v,ctrl-g,ctrl-p,ctrl-n,tab \
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
  ticket=$(printf '%s' "$first_line" | cut -d"$TAB" -f8)

  case "$KEY" in
    tab)
      [ "$MODE" = "active" ] && MODE="all" || MODE="active"
      continue
      ;;
    ctrl-s)
      if [ -z "$ws_path" ]; then
        echo "No WORKSPACE_SERVE_CMD configured for this window."; sleep 1; continue
      fi
      if [ "$ws_path" = "$CUR_TARGET" ]; then
        echo "Already serving this workspace."; sleep 1; continue
      fi
      serve_switch_to "$ws_path"
      continue
      ;;
    ctrl-r)
      if [ -z "$CUR_TARGET" ]; then echo "Nothing is being served."; sleep 1; continue; fi
      serve_switch_to "$CUR_TARGET"
      continue
      ;;
    ctrl-x)
      if [ -z "$CUR_TARGET" ]; then echo "Nothing is being served."; sleep 1; continue; fi
      serve_stop_current
      continue
      ;;
    ctrl-v)
      if [ -z "$CUR_TARGET" ]; then echo "Nothing is being served."; sleep 1; continue; fi
      tmux capture-pane -p -t "$SERVE_PANE" -S -500 | less -R +G
      continue
      ;;
    ctrl-g)
      if [ -z "$build_wt_path" ]; then
        echo "No WORKSPACE_BUILD_CONF=1 configured for this window."; sleep 1; continue
      fi
      trace_open_popup "$build_wt_path" || { sleep 1; continue; }
      exit 0
      ;;
    ctrl-p)
      if [ -z "$ws_path" ]; then
        echo "Not a workspace window."; sleep 1; continue
      fi
      deploy_run "$ws_path"
      continue
      ;;
    ctrl-n)
      if [ -z "$note_path" ]; then
        echo "No NOTE_PATH configured for this workspace."; sleep 1; continue
      fi
      tmux display-popup -E -w 90% -h 80% "nvim '$note_path'"
      continue
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
