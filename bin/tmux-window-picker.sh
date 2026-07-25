#!/bin/bash
# Vertical window picker: an fzf popup that lists every tmux window across all
# sessions as a vertical "tab" strip, with a live colored preview of each
# window's active pane. Enter switches to it (across sessions); Esc cancels.
# Bound to `prefix w` in .tmux.conf, replacing native choose-tree.
#
# Read-only navigator by design — it never creates, renames, or kills windows.
# Ticket-window lifecycle stays with wt / wtd so worktrees never get orphaned.
#
# Bash 3.2-clean (no associative arrays / mapfile). Rows already carry the
# 🔴/🟢 markers because tmux-agent-notify.sh renames the windows themselves.

set -u

TAB=$(printf '\t')

# One row per window: <session>\t<window_id>\t<"session │ window-name">.
# window_name already includes any 🔴/🟢 marker from tmux-agent-notify.sh.
list=$(tmux list-windows -a \
  -F "#{session_name}${TAB}#{window_id}${TAB}#{session_name} │ #{window_name}")
[ -z "$list" ] && exit 0

# catppuccin mocha palette, to match @catppuccin_flavor "mocha" in .tmux.conf.
mocha="--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,\
header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,fg+:#cdd6f4,\
prompt:#cba6f7,hl+:#f38ba8,border:#585b70"

selected=$(printf '%s\n' "$list" | fzf \
  --ansi \
  --delimiter="$TAB" \
  --with-nth=3 \
  --layout=reverse \
  --border=rounded \
  --margin=0 \
  --prompt='window ❯ ' \
  --pointer='▶' \
  --preview="tmux capture-pane -e -p -t {2}" \
  --preview-window='right,60%,border-left' \
  $mocha) || exit 0

[ -z "$selected" ] && exit 0

sess=$(printf '%s' "$selected" | cut -d"$TAB" -f1)
win=$(printf '%s' "$selected" | cut -d"$TAB" -f2)
[ -z "$win" ] && exit 0

tmux switch-client -t "$sess"
tmux select-window -t "$win"
