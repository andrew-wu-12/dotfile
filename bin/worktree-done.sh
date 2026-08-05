#!/bin/zsh
# Tear down the ticket worktree you are currently inside: close its tmux window,
# remove the worktree, delete the local branch (safely), and prune. Run this
# from inside the worktree you want to retire.
#
# Works against any git repo's linked worktrees, MOP or otherwise.
#
# Guardrails:
#   - refuses to run against a main checkout (see the .git file/dir check below)
#   - refuses a dirty worktree unless --force is passed (never destroys
#     uncommitted work silently)
#   - deletes the branch with `git branch -d` (safe): git refuses if the branch
#     is not merged, so a not-yet-merged ticket cannot be lost by accident

emulate -L zsh
set -u

source ~/.zshrc

FORCE=0
[[ "${1:-}" == "--force" || "${1:-}" == "-f" ]] && FORCE=1

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "wtd: not inside a git repo"; exit 1; }

# A linked worktree has a .git *file* (a pointer); the main checkout has a .git
# *directory*. This is the guard against running against the main checkout or
# any non-worktree repo.
if [[ ! -f "$ROOT/.git" ]]; then
    echo "wtd: $ROOT is not a linked worktree (no .git pointer file)"
    exit 1
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [[ $FORCE -eq 0 ]] && [[ -n "$(git status --porcelain)" ]]; then
    echo "wtd: worktree has uncommitted changes. Commit them or re-run with --force."
    git status --short
    exit 1
fi

echo "Tearing down worktree: $ROOT (branch $BRANCH)"

# Sibling .title file (mwt only; no-op for wt/plain worktrees). Removed here,
# once teardown is actually committed to, so it never outlives the worktree
# it was written for.
rm -f "${ROOT}.title"

# Close the tmux window tmux-dev-layout.sh created for this worktree. It names windows
# "<branch>(<repo>)", so recompute that and kill by exact name → window id (robust
# to slashes/parens in the name).
common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
case "$common_dir" in /*) ;; *) common_dir="$ROOT/$common_dir" ;; esac
WIN_NAME="${BRANCH}(${common_dir:h:t})"
tmux list-windows -a -F '#{window_id} #{window_name}' 2>/dev/null \
    | while IFS=' ' read -r wid wname; do
        [[ "$wname" == "$WIN_NAME" || "$wname" == *" $WIN_NAME" ]] && tmux kill-window -t "$wid"
      done

# If the single MOP `yarn serve` window (see tmux-serve-popup.sh) is currently
# targeting this worktree, stop it and clear the target first — otherwise
# `git worktree remove` fights a running process whose cwd is inside $ROOT.
SERVE_WIN_NAME="serve(mop-console-monorepo)"
tmux list-windows -a -F '#{window_id} #{window_name}' 2>/dev/null \
    | while IFS=' ' read -r wid wname; do
        [[ "$wname" == "$SERVE_WIN_NAME" || "$wname" == *" $SERVE_WIN_NAME" ]] || continue
        [[ "$(tmux show-option -w -t "$wid" -v @serve_target 2>/dev/null)" == "$ROOT" ]] || continue
        SERVE_PANE=$(tmux list-panes -t "$wid" -F '#{pane_id}' | head -1)
        echo "Stopping yarn serve (currently targeting this worktree)…"
        tmux send-keys -t "$SERVE_PANE" C-c
        tmux set-option -w -t "$wid" -u @serve_target
      done

# git worktree remove must run from outside the tree being removed. common_dir
# (computed above) is the main checkout's .git dir, so its parent is the main
# worktree root — generic across any repo, not just MOP.
cd "${common_dir:h}"
if [[ $FORCE -eq 1 ]]; then
    git worktree remove --force "$ROOT"
else
    git worktree remove "$ROOT"
fi

if [[ $FORCE -eq 1 ]]; then
    git branch -D "$BRANCH"
else
    git branch -d "$BRANCH" 2>/dev/null || \
        echo "Note: branch $BRANCH not deleted (unmerged). Delete manually with 'git branch -D $BRANCH' if intended."
fi

git worktree prune
echo "Done. Worktree removed."
