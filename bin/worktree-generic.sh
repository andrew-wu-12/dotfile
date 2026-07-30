#!/bin/zsh
# Generic worktree-native branch onboarding for any git repo (alias: wt).
# Unlike worktree-ticket.sh (mwt), this has no JIRA/ticket system: it takes a
# plain branch name, creates it off the repo's default branch if it doesn't
# already exist, and materializes it as a worktree — locally only, no push, no
# PR. Operates on whichever repo the cwd is inside, not a hardcoded path.

emulate -L zsh
set -u

source "${0:A:h}/worktree-lib.sh"
source ~/.zshrc

WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/project/worktrees}"

BRANCH_NAME="${1:-}"
if [[ -z "$BRANCH_NAME" ]]; then
    echo "Usage: wt <branch-name>"
    exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "wt: not inside a git repo"
    exit 1
}
REPO_NAME=$(wt_repo_name "$REPO_ROOT")
DIR_NAME="${BRANCH_NAME//\//-}"
WORKTREE_DIR="$WORKTREE_ROOT/$REPO_NAME/$DIR_NAME"

if [[ -e "$WORKTREE_DIR" ]]; then
    echo "Worktree already exists at $WORKTREE_DIR — opening it."
    wt_install_hooks "$WORKTREE_DIR"
    cd "$WORKTREE_DIR" && zsh ~/bin/tmux-dev-layout.sh
    exit 0
fi

cd "$REPO_ROOT"
git fetch origin

if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    echo "Branch $BRANCH_NAME already exists locally. Reusing."
elif git ls-remote --exit-code --heads origin "$BRANCH_NAME" >/dev/null 2>&1; then
    echo "Branch $BRANCH_NAME exists on origin. Tracking it."
    git branch "$BRANCH_NAME" "origin/$BRANCH_NAME"
else
    BASE_BRANCH=$(wt_default_base_branch origin) || {
        echo "wt: could not determine a default base branch (tried origin/HEAD, main, master)"
        exit 1
    }
    echo "Creating $BRANCH_NAME off origin/$BASE_BRANCH"
    git branch "$BRANCH_NAME" "origin/$BASE_BRANCH" || { echo "Failed to create branch $BRANCH_NAME"; exit 1; }
fi

echo "Creating worktree at $WORKTREE_DIR for $BRANCH_NAME"
mkdir -p "$WORKTREE_ROOT/$REPO_NAME"
git worktree add "$WORKTREE_DIR" "$BRANCH_NAME" || { echo "git worktree add failed"; exit 1; }

wt_clone_node_modules "$REPO_ROOT" "$WORKTREE_DIR"
wt_install_hooks "$WORKTREE_DIR"

echo "Worktree ready: $WORKTREE_DIR"
cd "$WORKTREE_DIR" && zsh ~/bin/tmux-dev-layout.sh
