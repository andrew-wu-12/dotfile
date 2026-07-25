#!/bin/zsh
# VSCode-style tmux dev layout for the current git repo.
#
#   +---------------------------+----------+
#   |          nvim (~3/4 h)    |          |
#   +---------------------------+  claude  |
#   |      command (~1/4 h)     | (~1/4 w) |
#   +---------------------------+----------+
#            left ~3/4 w
#
# One shared template applied at the current repo's root. Idempotent by
# window name (the repo dir): re-running just re-selects the repo's window.
# Bootstraps tmux if invoked from a bare terminal.

set -eu

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
  local p_nvim=$1 p_claude p_cmd
  p_claude=$(tmux split-window -h -l 25% -t "$p_nvim" -c "$repo_root" -P -F '#{pane_id}')
  p_cmd=$(tmux split-window -v -l 25% -t "$p_nvim" -c "$repo_root" -P -F '#{pane_id}')  # command pane: bare shell

  # Label each pane border with the repo name. pane-border-status is a
  # window-local option so other windows keep their default (off) look.
  local win; win=$(tmux display-message -p -t "$p_nvim" '#{window_id}')
  tmux set-option -w -t "$win" pane-border-status top
  tmux set-option -w -t "$win" pane-border-format ' #{pane_title} '
  tmux select-pane -t "$p_nvim"   -T "$repo_name"
  tmux select-pane -t "$p_cmd"    -T "$repo_name"
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

if [[ -n ${TMUX:-} ]]; then
  # Already inside tmux: add/select the window in the current session.
  session=$(tmux display-message -p '#S')
  win_id=$(window_id_for "$session" "$win_name")
  if [[ -n "$win_id" ]]; then
    tmux select-window -t "$win_id"
  else
    build_window "$session"
  fi
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
  tmux select-window -t "$win_id"
  exec tmux attach-session -t "$session"
fi
