#!/bin/bash
# Vertical window picker + MOP yarn-serve control: an fzf popup listing every
# tmux window across all sessions as a vertical stack of cards.
#
#   enter   switch to the highlighted window (across sessions) and exit
#   ctrl-s  set the highlighted window's worktree as the yarn-serve target
#           (does NOT switch — "check out the window, decide separately
#           whether to serve from it")
#   ctrl-r  restart whatever is currently served
#   ctrl-x  stop whatever is currently served
#   ctrl-v  view the full serve log
#   esc     cancel
#
# ctrl-s/ctrl-r/ctrl-x/ctrl-v act and loop back into a refreshed picker
# instead of closing the popup; enter/esc are the only ways out. This used to
# be two separate popups (`prefix w` for switching, `prefix n` for serve
# control via tmux-serve-popup.sh) — merged here since both start from "which
# window am I looking at," and serve-targeting only makes sense for a
# worktree that already has one open. Shared serve helpers live in
# tmux-serve-lib.sh (also sourced by worktree-done.sh).
#
# Each card is a multi-line fzf item (fzf --read0, fzf >= 0.44 required for
# multi-line item rendering): a bold header line ("session │ window-name",
# window-name already carrying any 🔴/🟢 marker from tmux-agent-notify.sh),
# then optionally a dim ticket-title line (from @ticket_title, set by
# worktree-ticket.sh) and/or a serve status/marker line. The header is
# deliberately the LAST tab-delimited field (session, window_id, worktree
# path, header) rather than the first three: --with-nth/--delimiter split
# fields across the whole multi-line record, not per physical line, so any
# body text appended after the header (title, status lines) has to land
# after the last tab or it silently falls outside --with-nth's display
# range. fzf's multi-line matching searches the whole card as a side effect
# of this layout.
#
# The preview pane (right 60%) runs tmux-ticket-status.sh against the
# highlighted card's worktree path (field {3}, blank/placeholder for
# non-MOP windows) — see PREVIEW_CMD below. tmux-ticket-status.sh caches its
# report per worktree, so re-invoking it on every highlighted row is just a
# cache read, not a live fetch. ctrl-l busts the cache for the highlighted
# card and refreshes the preview in place — see the --bind below.
#
# The hidden serve window itself never appears in the list — it's plumbing,
# not somewhere to jump to.
#
# Bash 3.2-clean (no associative arrays / mapfile).

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tmux-serve-lib.sh
source "$SCRIPT_DIR/tmux-serve-lib.sh"

TAB=$(printf '\t')
BOLD=$'\033[1m'
DIM=$'\033[38;2;127;132;156m'  # catppuccin mocha "overlay1"
RESET=$'\033[0m'

mocha="--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,\
header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,fg+:#cdd6f4,\
prompt:#cba6f7,hl+:#f38ba8,border:#585b70"

# {3} is the worktree path field (empty for non-MOP-worktree windows) — fzf
# quotes placeholder substitutions itself, so this is safe as-is. Re-invoked
# on every highlighted row (including transient ones while scrolling), but
# tmux-ticket-status.sh caches its report per worktree, so this is a cache
# read on every cursor move, not a live fetch — see tmux-ticket-status.sh.
PREVIEW_CMD='wt={3}; if [ -z "$wt" ]; then printf "(not a MOP ticket window)\n"; else ~/bin/tmux-ticket-status.sh "$wt"; fi'

# ctrl-l busts the highlighted card's ticket-status cache, then refreshes
# the preview — the follow-up preview invocation (PREVIEW_CMD above) is a
# plain cache miss at that point, so it re-fetches live and repopulates.
# No-op for non-MOP windows: --reload "" resolves nothing and exits quietly.
RELOAD_BIND='ctrl-l:execute-silent(~/bin/tmux-ticket-status.sh --reload {3})+refresh-preview'

SERVE_INFO=$(serve_ensure_window)
SERVE_WIN=$(printf '%s' "$SERVE_INFO" | cut -d' ' -f2)
SERVE_PANE=$(printf '%s' "$SERVE_INFO" | cut -d' ' -f3)

list_file=$(mktemp)
trap 'rm -f "$list_file"' EXIT

# --- start/stop actions on the hidden serve window ---------------------

serve_switch_to() {  # $1 = worktree path to serve
  local target="$1" cmd
  tmux send-keys -t "$SERVE_PANE" C-c
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

  tmux send-keys -t "$SERVE_PANE" "cd '$target' && yarn serve" Enter
  tmux set-option -w -t "$SERVE_WIN" @serve_target "$target"

  sleep 1
}

serve_stop_current() {
  tmux send-keys -t "$SERVE_PANE" C-c
  tmux set-option -w -t "$SERVE_WIN" -u @serve_target
  sleep 1
}

# --- card list -----------------------------------------------------------
#
# Written to a file, not a variable: bash silently drops embedded NUL bytes
# from variables, which would collapse every card into one unselectable blob.
#
# Windows are only checked against the (relatively expensive) git resolution
# below when their name ends in the MOP monorepo suffix — a cheap string
# pre-filter ahead of the per-window git calls.
build_list() {
  serve_compute_status
  CUR_TARGET=$(serve_current_target "$SERVE_WIN")
  : > "$list_file"

  tmux list-windows -a \
    -F "#{session_name}${TAB}#{window_id}${TAB}#{session_name} │ #{window_name}${TAB}#{@ticket_title}${TAB}#{pane_current_path}" \
    | while IFS="$TAB" read -r sess winid header title panepath; do
        case "$header" in
          *" │ $SERVE_WIN_NAME"|*" │ "*" $SERVE_WIN_NAME")
            continue  # hide the hidden serve window (suffix-matched like serve_find_window)
            ;;
        esac

        wt_path=""
        case "$header" in
          *"(mop-console-monorepo)")
            top=$(git -C "$panepath" rev-parse --show-toplevel 2>/dev/null)
            if [ -n "$top" ] && serve_is_mop_path "$top"; then
              wt_path="$top"
            fi
            ;;
        esac

        record="${sess}${TAB}${winid}${TAB}${wt_path}${TAB}${BOLD}${header}${RESET}"
        [ -n "$title" ] && record="${record}
  ${DIM}${title}${RESET}"

        if [ -n "$wt_path" ]; then
          if [ "$wt_path" = "$CUR_TARGET" ]; then
            status_line=$(printf '%s %s   http://localhost:%s' "$(serve_status_dot)" "$STATUS" "$SERVE_PORT")
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

        printf '%s\0' "$record" >> "$list_file"
      done
}

# --- main loop -------------------------------------------------------------
#
# enter/esc exit; ctrl-s/ctrl-r/ctrl-x/ctrl-v act and loop back into a
# refreshed picker, same idiom as tmux-serve-popup.sh used to.
while true; do
  build_list
  [ -s "$list_file" ] || exit 0

  HEADER=$(printf ' %s %-9s serving: %-30s  http://localhost:%s\n enter:switch  ctrl-s:serve  ctrl-r:restart  ctrl-x:stop  ctrl-v:view log  ctrl-l:reload ticket status' \
    "$(serve_status_dot)" "$STATUS" "$(serve_target_label "$CUR_TARGET")" "$SERVE_PORT")

  result=$(fzf \
    --read0 \
    --ansi \
    --gap=1 \
    --delimiter="$TAB" \
    --with-nth=4 \
    --layout=reverse \
    --border=rounded \
    --margin=0 \
    --header="$HEADER" \
    --header-first \
    --prompt='window ❯ ' \
    --pointer='▶' \
    --expect=ctrl-s,ctrl-r,ctrl-x,ctrl-v \
    --bind="$RELOAD_BIND" \
    --preview="$PREVIEW_CMD" \
    --preview-window=right:60%:wrap \
    $mocha < "$list_file") || exit 0

  [ -z "$result" ] && exit 0

  # --expect prepends the pressed key as its own line (empty for a plain
  # enter), ahead of the selected card — so the card's header line, which
  # would otherwise be line 1, is line 2.
  KEY=$(printf '%s\n' "$result" | sed -n '1p')
  first_line=$(printf '%s\n' "$result" | sed -n '2p')
  sess=$(printf '%s' "$first_line" | cut -d"$TAB" -f1)
  winid=$(printf '%s' "$first_line" | cut -d"$TAB" -f2)
  wt_path=$(printf '%s' "$first_line" | cut -d"$TAB" -f3)

  case "$KEY" in
    ctrl-s)
      if [ -z "$wt_path" ]; then
        echo "Not a MOP worktree window."; sleep 1; continue
      fi
      if [ "$wt_path" = "$CUR_TARGET" ]; then
        echo "Already serving this worktree."; sleep 1; continue
      fi
      serve_switch_to "$wt_path"
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
  esac

  [ -z "$winid" ] && continue
  tmux switch-client -t "$sess"
  tmux select-window -t "$winid"
  exit 0
done
