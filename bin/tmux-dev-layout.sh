#!/bin/zsh
# VSCode-style tmux dev layout for the current git repo.
#
#   +---------------------------+----------+
#   |           nvim            |  claude  |
#   |         (~3/4 h)          | (~1/4 w) |
#   +---------------------------+----------+
#
# Idempotent by window name (the repo dir): re-running re-selects the
# window. Bootstraps tmux if invoked from a bare terminal.
#
# Default rebuilds the layout on the current window in place. -n/--new-window
# opens a new window instead. Either way, a matching existing window is
# selected, never duplicated.
#
# $TICKET_TITLE (worktree-ticket.sh, mwt only) is stashed as the
# @ticket_title window user option for tmux-window-picker.sh's card body.
#
# Session is resolved per repo, not the currently attached session:
# SESSION_GROUP from .workspace.conf, walked $HOME down to the repo root
# (outer to inner — same file tmux-window-picker.sh reads WORKSPACE_* from).
# No SESSION_GROUP anywhere in the ancestry falls back to the repo name as
# its own session. A target session other than the one attached switches
# sessions instead of overriding the current window.

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

# Window name: "<branch>(<repo>)". Repo name comes from the parent of the
# shared git common dir, so it's the real project name even inside a linked
# worktree (repo_root's own basename is just the ticket there).
branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
case "$common_dir" in /*) ;; *) common_dir="$repo_root/$common_dir" ;; esac
main_repo=${common_dir:h:t}
win_name="${branch_name}(${main_repo})"

# Sets $SESSION_GROUP by sourcing every ".workspace.conf" from $HOME down to
# path $1, outer to inner. Unset if none exists, or none set it.
resolve_session_group() {  # $1 = repo root
  local target=$1 dir dirs
  unset SESSION_GROUP
  target=$(cd "$target" 2>/dev/null && pwd) || return 1
  dirs=()
  dir=$target
  while true; do
    dirs=("$dir" $dirs)
    [[ "$dir" == "$HOME" ]] && break
    [[ "$dir" == "/" ]] && break
    dir=${dir:h}
  done
  for dir in $dirs; do
    [[ -f "$dir/.workspace.conf" ]] && source "$dir/.workspace.conf"
  done
}

resolve_session_group "$repo_root"
session_target="${SESSION_GROUP:-$main_repo}"

# Splits the claude pane off nvim pane $1, launches both tools, focuses nvim.
layout_panes() {  # nvim_pane_id
  local p_nvim=$1 p_claude
  p_claude=$(tmux split-window -h -l 25% -t "$p_nvim" -c "$repo_root" -P -F '#{pane_id}')

  # pane-border-status is window-local: only this window shows pane titles.
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

# Ensures session $1 exists and has this repo's window (creating either as
# needed). Prints the window id.
ensure_session_and_window() {  # $1 = target session
  local target=$1 win_id
  if tmux has-session -t "=$target" 2>/dev/null; then
    win_id=$(window_id_for "$target" "$win_name")
    [[ -n "$win_id" ]] || { build_window "$target"; win_id=$(window_id_for "$target" "$win_name"); }
  else
    tmux new-session -d -s "$target" -n "$win_name" -c "$repo_root"
    win_id=$(window_id_for "$target" "$win_name")
    layout_panes "$(tmux list-panes -t "$win_id" -F '#{pane_id}' | head -1)"
  fi
  print -r -- "$win_id"
}

# Rebuilds the layout on the window currently in view: kills every pane but
# this script's own, renames the window, hands that pane to layout_panes.
#
# Can't respawn-kill the current pane (it would kill this script mid-flight).
# `cd`/`nvim` are queued via send-keys instead — the shell picks them up once
# the script exits and reads stdin again.
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

# Echoes the window id for name $2 in session $1. Matches exactly or with a
# leading notification marker (tmux-agent-notify.sh's "<marker><name>").
window_id_for() {  # session, window_name
  tmux list-windows -t "$1" -F '#{window_id} #{window_name}' 2>/dev/null \
    | while IFS=' ' read -r id name; do
        [[ "$name" == "$2" || "$name" == *" $2" ]] && { print -r -- "$id"; break; }
      done
  return 0  # "no match" is not an error; without this `set -e` aborts the caller
}

# Stashes $TICKET_TITLE (if set) as a window user option.
tag_ticket_title() {  # window_id
  [[ -n "${TICKET_TITLE:-}" && -n "${1:-}" ]] || return 0
  tmux set-option -w -t "$1" @ticket_title "$TICKET_TITLE"
}

if [[ -n ${TMUX:-} ]]; then
  cur_session=$(tmux display-message -p '#S')
  if [[ "$cur_session" == "$session_target" ]]; then
    # Same session: reuse, build, or override the window in place.
    win_id=$(window_id_for "$cur_session" "$win_name")
    if [[ -n "$win_id" ]]; then
      tmux select-window -t "$win_id"
    elif [[ "$NEW_WINDOW" == 1 ]]; then
      build_window "$cur_session"
      win_id=$(window_id_for "$cur_session" "$win_name")
    else
      win_id=$(override_window)
    fi
    tag_ticket_title "$win_id"
  else
    # Different session: switch to (creating if needed) the target session.
    win_id=$(ensure_session_and_window "$session_target")
    tag_ticket_title "$win_id"
    tmux switch-client -t "$session_target"
    tmux select-window -t "$win_id"
  fi
else
  # Bare terminal: attach to the repo's target session, creating it if needed.
  win_id=$(ensure_session_and_window "$session_target")
  tag_ticket_title "$win_id"
  tmux select-window -t "$win_id"
  exec tmux attach-session -t "$session_target"
fi
