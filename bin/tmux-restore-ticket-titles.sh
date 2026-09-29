#!/bin/zsh
# Re-applies the @ticket_title window option after a tmux-resurrect restore: resurrect doesn't capture custom
# window options, so restored ticket windows lose the title on the picker's card (only the window name survives).
# Registered as @resurrect-hook-post-restore-all in .tmux.conf (runs once, after every window/pane is restored).
# worktree-ticket.sh writes the title to $WORKTREE_ROOT/<repo>/<ticket>.title, next to (not inside) the worktree
# so it never shows in that worktree's `git status`; this reads it back for windows whose pane sits in a
# worktree under $WORKTREE_ROOT.

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
