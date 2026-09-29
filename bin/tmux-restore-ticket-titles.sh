#!/bin/zsh
# Re-applies the @ticket_title window user option after a tmux-resurrect
# restore. tmux-resurrect's default state capture (sessions/windows/panes/
# layout/cwd/running-program) does not include custom window user options, so
# a full tmux-server restart (terminal quit + continuum auto-restore, or a
# manual prefix Ctrl-R) recreates ticket worktree windows without the ticket
# title tmux-window-picker.sh shows on their card — only the window name
# ("<branch>(<repo>)", which resurrect does restore) survives.
#
# Registered as @resurrect-hook-post-restore-all in .tmux.conf, so resurrect's
# restore.sh runs this once, after every window/pane is already restored.
#
# worktree-ticket.sh (mwt) writes the ticket title to a sibling file next to
# (not inside) the worktree dir — $WORKTREE_ROOT/<repo>/<ticket>.title — so it
# never shows up as untracked in that worktree's own `git status`. This script
# reads it back for any window whose pane currently sits in a worktree under
# $WORKTREE_ROOT.

emulate -L zsh
set -u

worktree_root="${WORKTREE_ROOT:-$HOME/project/worktrees}"

tmux list-windows -a -F '#{window_id} #{pane_current_path}' 2>/dev/null \
  | while IFS=' ' read -r win_id pane_path; do
      root=$(git -C "$pane_path" rev-parse --show-toplevel 2>/dev/null) || continue
      case "$root" in
        "$worktree_root"/*) ;;
        *) continue ;;
      esac
      title_file="${root}.title"
      [[ -f "$title_file" ]] || continue
      title=$(<"$title_file")
      [[ -n "$title" ]] || continue
      tmux set-option -w -t "$win_id" @ticket_title "$title"
    done

exit 0
