#!/bin/zsh
# Tear down the ticket worktree you are inside (any repo's linked worktrees, MOP or not): close its tmux
# window, remove the worktree, delete the local branch, prune.
# Guardrails: refuses a main checkout (.git file-vs-dir check below); refuses a dirty worktree unless --force;
# `git branch -d` makes git refuse an unmerged branch, so a not-yet-merged ticket can't be lost by accident.
emulate -L zsh
set -u

source ~/.zshrc
source "${0:A:h}/tmux-serve-lib.sh"

FORCE=0
[[ "${1:-}" == "--force" || "${1:-}" == "-f" ]] && FORCE=1

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "wtd: not inside a git repo"; exit 1; }

# A linked worktree has a .git *file* (a pointer); the main checkout has a .git *directory*. Guards against
# running on the main checkout or any non-worktree repo.
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

# Sibling .title and ticket-status cache files (mwt only; no-op otherwise), removed once teardown is committed
# to so neither outlives the worktree.
rm -f "${ROOT}.title" "${ROOT}.status-cache.json"

# Close the window tmux-dev-layout.sh named "<branch>(<repo>)": recompute the name and kill by exact name ->
# window id (robust to slashes/parens in the name).
common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
case "$common_dir" in /*) ;; *) common_dir="$ROOT/$common_dir" ;; esac
WIN_NAME="${BRANCH}(${common_dir:h:t})"
tmux list-windows -a -F '#{window_id} #{window_name}' 2>/dev/null \
    | while IFS=' ' read -r wid wname; do
        [[ "$wname" == "$WIN_NAME" || "$wname" == *" $WIN_NAME" ]] && tmux kill-window -t "$wid"
      done

# If the dev server is targeting this worktree, stop it first: `git worktree remove` fights a running process
# whose cwd is inside $ROOT.
serve_stop_if_target "$ROOT"

# `git worktree remove` must run from outside the tree being removed; common_dir's parent is the main
# worktree root, for any repo.
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
