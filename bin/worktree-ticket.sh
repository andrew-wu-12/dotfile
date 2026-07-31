#!/bin/zsh
# Required parameters
# @raycast.schemaVersion 1
# @raycast.title Worktree Ticket
# @raycast.mode fullOutput
# @raycast.packageName Worktree Ticket
# @raycast.icon 🌳
#
# Optional parameters
# @raycast.argument1 {"type": "text", "placeholder": "DEV Ticket Number" }
#
# Worktree-native ticket onboarding for the MOP monorepo (alias: mwt). Unlike
# checkout-ticket.sh (crt), this never moves the main checkout's HEAD and never
# stashes: branches are created without checkout (via commit-tree), then
# materialized as a git worktree under $WORKTREE_ROOT so you can context-switch
# between tickets without stash/pop. For non-MOP repos, see worktree-generic.sh
# (alias: wt).

emulate -L zsh
set -u

# Shared JIRA/PR helpers and worktree-materialization helpers. ${0:A:h} =
# symlink-resolved dir of this script, so this resolves through the ~/bin
# symlink.
source "${0:A:h}/ticket-lib.sh"
source "${0:A:h}/worktree-lib.sh"

# Source zshrc after function definitions to avoid alias conflicts, and to load
# $JIRA_TOKEN / $MOP_MONOREPO_PATH.
source ~/.zshrc

WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/project/worktrees}"

# Ensure a branch exists and has a draft PR, without checking it out anywhere.
# The branch is created one empty commit ahead of its base (so gh has a diff to
# open the PR against), pushed, and a draft PR is opened. If the branch already
# exists locally or on origin, it is reused and no PR is created.
#   $1 branch data (from pr_get_params)  $2 base ref (e.g. origin/main)  $3 pr base branch
function wt_ensure_branch() {
    local BRANCH_DATA="$1" BASE_REF="$2" PR_BASE="$3"
    local NAME=$(get_from_json "$BRANCH_DATA" ".branch_name")
    local TITLE=$(pr_get_title "$BRANCH_DATA")
    local CONTENT=$(pr_get_content "$BRANCH_DATA")

    if git show-ref --verify --quiet "refs/heads/$NAME"; then
        echo "Branch $NAME already exists locally. Reusing."
        return 0
    fi
    if git ls-remote --exit-code --heads origin "$NAME" >/dev/null 2>&1; then
        echo "Branch $NAME exists on origin. Tracking it."
        git branch "$NAME" "origin/$NAME"
        return 0
    fi

    local BASE_SHA TREE NEW_SHA
    BASE_SHA=$(git rev-parse "$BASE_REF") || return 1
    TREE=$(git rev-parse "$BASE_REF^{tree}") || return 1
    NEW_SHA=$(git commit-tree "$TREE" -p "$BASE_SHA" -m "Initial draft for branch $NAME") || return 1
    git branch "$NAME" "$NEW_SHA"
    git push -u origin "$NAME"
    gh pr create -a @me -B "$PR_BASE" -H "$NAME" -t "$TITLE" -b "$CONTENT" -d
}

TICKET_NUMBER="${1:-}"
if [[ -z "$TICKET_NUMBER" ]]; then
    echo "Usage: mwt <MOP-XXXX>"
    exit 1
fi

TICKET_DATA=$(get_ticket_content "$TICKET_NUMBER")
TICKET_ISSUE_TYPE=$(get_from_json "$TICKET_DATA" ".issue_type")
PARENT_DATA=$(get_ticket_parent "$TICKET_DATA")
PARENT_TICKET_NUMBER=$(get_from_json "$PARENT_DATA" ".ticket_number")

# Picked up by tmux-dev-layout.sh to tag the window with @ticket_title, so
# tmux-window-picker.sh can show it without a live JIRA call.
export TICKET_TITLE=$(get_from_json "$TICKET_DATA" ".summary")
echo "TICKET_NUMBER: $TICKET_NUMBER
TICKET_ISSUE_TYPE: $TICKET_ISSUE_TYPE
PARENT_TICKET_NUMBER: $PARENT_TICKET_NUMBER"

REPO_NAME=$(wt_repo_name "$MOP_MONOREPO_PATH")
WORKTREE_DIR="$WORKTREE_ROOT/$REPO_NAME/$TICKET_NUMBER"
if [[ -e "$WORKTREE_DIR" ]]; then
    echo "Worktree already exists at $WORKTREE_DIR — opening it."
    wt_install_hooks "$WORKTREE_DIR"
    cd "$WORKTREE_DIR" && zsh ~/bin/tmux-dev-layout.sh
    exit 0
fi

# All branch plumbing runs from the main checkout, but only via refs — HEAD and
# the working tree there are never touched.
cd "$MOP_MONOREPO_PATH"
git fetch origin

if [[ "$TICKET_ISSUE_TYPE" == "Production Support" ]]; then
    FEATURE_DATA=$(pr_get_params "$TICKET_DATA" main hotfix)
    FEATURE_BRANCH=$(get_from_json "$FEATURE_DATA" ".branch_name")
    wt_ensure_branch "$FEATURE_DATA" origin/main main || { echo "Failed to prepare $FEATURE_BRANCH"; exit 1; }
else
    UAT_BRANCH="uat/$PARENT_TICKET_NUMBER"
    UAT_DATA=$(pr_get_params "$PARENT_DATA" main uat)
    wt_ensure_branch "$UAT_DATA" origin/main main || { echo "Failed to prepare $UAT_BRANCH"; exit 1; }

    FEATURE_DATA=$(pr_get_params "$TICKET_DATA" "$UAT_BRANCH" feature)
    FEATURE_BRANCH=$(get_from_json "$FEATURE_DATA" ".branch_name")
    wt_ensure_branch "$FEATURE_DATA" "refs/heads/$UAT_BRANCH" "$UAT_BRANCH" || { echo "Failed to prepare $FEATURE_BRANCH"; exit 1; }
fi

echo "Creating worktree at $WORKTREE_DIR for $FEATURE_BRANCH"
mkdir -p "$WORKTREE_ROOT/$REPO_NAME"
git worktree add "$WORKTREE_DIR" "$FEATURE_BRANCH" || { echo "git worktree add failed"; exit 1; }

wt_clone_node_modules "$MOP_MONOREPO_PATH" "$WORKTREE_DIR"
wt_install_hooks "$WORKTREE_DIR"

echo "Worktree ready: $WORKTREE_DIR"
cd "$WORKTREE_DIR" && zsh ~/bin/tmux-dev-layout.sh
