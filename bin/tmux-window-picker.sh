#!/bin/bash
# Vertical window picker: an fzf popup that lists every tmux window across all
# sessions as a vertical stack of cards. Enter switches to it (across
# sessions); Esc cancels. Bound to `prefix w` in .tmux.conf, replacing native
# choose-tree.
#
# Each card is a multi-line fzf item (fzf --read0, fzf >= 0.44 required for
# multi-line item rendering): a bold header line ("session │ window-name",
# window-name already carrying any 🔴/🟢 marker from tmux-agent-notify.sh),
# plus for mwt ticket windows a dim indented ticket-title line (from the
# @ticket_title window option set by worktree-ticket.sh) and a dim indented
# Claude-status line derived from the marker. Plain wt/dev windows have
# neither body line, so their card is just the header. No live preview pane —
# fzf's multi-line matching searches the whole card (header + body) as a
# side effect of this layout; there's no fzf option to scope it to the header
# alone once items are multi-line.
#
# Read-only navigator by design — it never creates, renames, or kills windows.
# Ticket-window lifecycle stays with wt / wtd so worktrees never get orphaned.
#
# Bash 3.2-clean (no associative arrays / mapfile).

set -u

TAB=$(printf '\t')
BOLD=$'\033[1m'
DIM=$'\033[38;2;127;132;156m'  # catppuccin mocha "overlay1"
RESET=$'\033[0m'

# One row per window: <session>\t<window_id>\t<header>\t<ticket_title>.
# window_name already includes any 🔴/🟢 marker from tmux-agent-notify.sh.
# @ticket_title is empty for non-mwt windows (unset tmux user option).
raw=$(tmux list-windows -a \
  -F "#{session_name}${TAB}#{window_id}${TAB}#{session_name} │ #{window_name}${TAB}#{@ticket_title}")
[ -z "$raw" ] && exit 0

# Build the NUL-delimited, multi-line card list fzf expects with --read0.
# Written straight to a temp file via printf, not accumulated in a bash
# variable: bash (unlike zsh) silently drops embedded NUL bytes from
# variables, which collapsed every card into one unselectable blob.
list_file=$(mktemp)
trap 'rm -f "$list_file"' EXIT

while IFS="$TAB" read -r sess winid header title; do
  case "$header" in
    *"🔴 "*) claude_status="Needs confirmation" ;;
    *"🟢 "*) claude_status="Step complete" ;;
    *) claude_status="" ;;
  esac

  record="${sess}${TAB}${winid}${TAB}${BOLD}${header}${RESET}"
  [ -n "$title" ] && record="${record}
  ${DIM}${title}${RESET}"
  [ -n "$claude_status" ] && record="${record}
  ${DIM}${claude_status}${RESET}"

  printf '%s\0' "$record" >> "$list_file"
done <<EOF
$raw
EOF

# catppuccin mocha palette, to match @catppuccin_flavor "mocha" in .tmux.conf.
mocha="--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,\
header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,fg+:#cdd6f4,\
prompt:#cba6f7,hl+:#f38ba8,border:#585b70"

selected=$(fzf \
  --read0 \
  --ansi \
  --gap=1 \
  --delimiter="$TAB" \
  --with-nth=3 \
  --layout=reverse \
  --border=rounded \
  --margin=0 \
  --prompt='window ❯ ' \
  --pointer='▶' \
  $mocha < "$list_file") || exit 0

[ -z "$selected" ] && exit 0

# Only the header (first) line of the selected card carries the session /
# window-id fields — body lines have no tabs.
first_line=$(printf '%s\n' "$selected" | head -1)
sess=$(printf '%s' "$first_line" | cut -d"$TAB" -f1)
win=$(printf '%s' "$first_line" | cut -d"$TAB" -f2)
[ -z "$win" ] && exit 0

tmux switch-client -t "$sess"
tmux select-window -t "$win"
