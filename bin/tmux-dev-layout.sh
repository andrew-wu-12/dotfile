#!/bin/zsh
# VSCode-style tmux dev layout for the current git repo.
#
#   +---------------------------+----------+
#   |           nvim            |  claude  |
#   |         (~3/4 h)          | (~1/4 w) |
#   +---------------------------+----------+
#
# One shared template applied at the current repo's root. Idempotent by
# window name (the repo dir): re-running just re-selects the repo's window.
# Bootstraps tmux if invoked from a bare terminal.
#
# Default: rebuilds the layout onto the CURRENT window (killing its other
# panes and renaming it) rather than spawning a new tab. Pass -n/--new-window
# to open the layout in a new window instead, the old behavior. Either way, if
# a window matching this repo/branch already exists, it's just selected — the
# current window is never overridden with a duplicate.
#
# If $TICKET_TITLE is set (worktree-ticket.sh exports it for mwt tickets),
# it's stashed as the @ticket_title window user option so
# tmux-window-picker.sh can show it on the window's card without a live JIRA
# call. Left unset for wt/plain dev windows.

set -eu

NEW_WINDOW=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--new-window) NEW_WINDOW=1; shift ;;
    *) print -u2 "tmux-dev-layout: unknown argument: $1"; exit 1 ;;
  esac
done

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  print -u2 "tmux-dev-layout: not inside a git repo"
  exit 1
}
repo_name=${repo_root:t}

# Window name is universally "<branch>(<repo>)". The repo name comes from the
# parent of the shared git common dir, so it is the real project name even from
# inside a linked worktree (where repo_root's basename is just the ticket).
branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
case "$common_dir" in /*) ;; *) common_dir="$repo_root/$common_dir" ;; esac
main_repo=${common_dir:h:t}
win_name="${branch_name}(${main_repo})"

# Given the pane id of the (already-created) nvim pane, carve out the claude
# column and the command pane, launch the tools, and focus nvim.
layout_panes() {  # nvim_pane_id
  local p_nvim=$1 p_claude
  p_claude=$(tmux split-window -h -l 25% -t "$p_nvim" -c "$repo_root" -P -F '#{pane_id}')

  # Label each pane border with the repo name. pane-border-status is a
  # window-local option so other windows keep their default (off) look.
  local win; win=$(tmux display-message -p -t "$p_nvim" '#{window_id}')
  tmux set-option -w -t "$win" pane-border-status top
  tmux set-option -w -t "$win" pane-border-format ' #{pane_title} '
  tmux select-pane -t "$p_nvim"   -T "$repo_name"
  tmux select-pane -t "$p_claude" -T "$repo_name"

  tmux send-keys -t "$p_nvim" 'nvim' C-m
  tmux send-keys -t "$p_claude" 'claude' C-m
  tmux select-pane -t "$p_nvim"
}

build_window() {  # session
  local p_nvim
  p_nvim=$(tmux new-window -a -t "$1:" -n "$win_name" -c "$repo_root" -P -F '#{pane_id}')
  layout_panes "$p_nvim"
}

# Default path: rebuild the layout on the window currently in view instead of
# opening a new one. Kills every pane but the one this script itself is
# running in, renames the window, and hands that pane to layout_panes.
#
# The current pane can't be respawn-killed like a normal reset — this script's
# own process is running in it, and killing it here would kill the script
# mid-flight (respawn-pane -k was tried and does exactly that: the pane's
# process dies before rename-window/layout_panes ever run). Instead, `cd` and
# `nvim` are queued via send-keys: the pty just buffers those keystrokes while
# this script owns the foreground, and its own shell picks them up the moment
# the script exits and stdin is read again — the same type-ahead-after-a-
# command-exits behavior a plain terminal gives you.
override_window() {
  local cur_win cur_pane
  cur_win=$(tmux display-message -p '#{window_id}')
  cur_pane=$(tmux display-message -p '#{pane_id}')
  tmux list-panes -t "$cur_win" -F '#{pane_id}' | while IFS= read -r pid; do
    [[ "$pid" == "$cur_pane" ]] || tmux kill-pane -t "$pid"
  done
  tmux rename-window -t "$cur_win" "$win_name"
  tmux send-keys -t "$cur_pane" "cd \"$repo_root\"" C-m
  layout_panes "$cur_pane"
  print -r -- "$cur_win"
}

# Echo the id of the window for $2 in session $1. Matches the canonical name
# exactly or with a leading notification marker (tmux-agent-notify.sh renames windows
# to "<marker><canonical>"), so a flagged window is reused, not duplicated.
window_id_for() {  # session, window_name
  tmux list-windows -t "$1" -F '#{window_id} #{window_name}' 2>/dev/null \
    | while IFS=' ' read -r id name; do
        [[ "$name" == "$2" || "$name" == *" $2" ]] && { print -r -- "$id"; break; }
      done
  return 0  # "no match" is not an error; without this `set -e` aborts the caller
}

# Stash $TICKET_TITLE (if set) as a window user option, for
# tmux-window-picker.sh's card body. No-op for wt/plain dev windows.
tag_ticket_title() {  # window_id
  [[ -n "${TICKET_TITLE:-}" && -n "${1:-}" ]] || return 0
  tmux set-option -w -t "$1" @ticket_title "$TICKET_TITLE"
}

if [[ -n ${TMUX:-} ]]; then
  # Already inside tmux: add/select the window in the current session.
  session=$(tmux display-message -p '#S')
  win_id=$(window_id_for "$session" "$win_name")
  if [[ -n "$win_id" ]]; then
    tmux select-window -t "$win_id"
  elif [[ "$NEW_WINDOW" == 1 ]]; then
    build_window "$session"
    win_id=$(window_id_for "$session" "$win_name")
  else
    win_id=$(override_window)
  fi
  tag_ticket_title "$win_id"
else
  # Bare terminal: attach to the most-recently-used session if a server is
  # running, otherwise start a fresh 'main' session.
  if tmux list-sessions >/dev/null 2>&1; then
    session=$(tmux list-sessions -F '#{session_last_attached} #{session_name}' \
      | sort -rn | head -1 | cut -d' ' -f2-)
    win_id=$(window_id_for "$session" "$win_name")
    [[ -n "$win_id" ]] || { build_window "$session"; win_id=$(window_id_for "$session" "$win_name"); }
  else
    session=main
    tmux new-session -d -s "$session" -n "$win_name" -c "$repo_root"
    win_id=$(window_id_for "$session" "$win_name")
    layout_panes "$(tmux list-panes -t "$win_id" -F '#{pane_id}' | head -1)"
  fi
  tag_ticket_title "$win_id"
  tmux select-window -t "$win_id"
  exec tmux attach-session -t "$session"
fi
