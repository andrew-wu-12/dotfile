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
# Worktree-native ticket onboarding for the MOP monorepo (alias: mwt). Never moves the main checkout's HEAD and
# never stashes: branches are created without checkout (commit-tree), then materialized as a worktree under
# $WORKTREE_ROOT. For non-MOP repos, see worktree-generic.sh (alias: wt).

emulate -L zsh
set -u

# ${0:A:h} is the symlink-resolved script dir, so this works through the ~/bin symlink.
source "${0:A:h}/ticket-lib.sh"
source "${0:A:h}/worktree-lib.sh"

# After the function definitions to avoid alias conflicts; loads $JIRA_TOKEN / $MOP_MONOREPO_PATH.
source ~/.zshrc

WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/project/worktrees}"

DEV_LAYOUT_FLAGS=()
SKIP_PR=0
while [[ "${1:-}" == -n || "${1:-}" == --new-window || "${1:-}" == --no-pr ]]; do
    case "${1:-}" in
        -n|--new-window) DEV_LAYOUT_FLAGS=(-n) ;;
        --no-pr) SKIP_PR=1 ;;
    esac
    shift
done

# Ensure a branch exists (created without checkout) and optionally has a draft PR. The branch is one empty
# commit ahead of its base so gh has a diff to open the PR against; a branch that already exists locally or on
# origin is reused and gets no PR.
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
    [[ "$SKIP_PR" -eq 1 ]] && return 0
    gh pr create -a @me -B "$PR_BASE" -H "$NAME" -t "$TITLE" -b "$CONTENT" -d
}

# Populates $WORKTREE_DIR/systemOptions: generated, gitignored data (`yarn download-options`) that a fresh
# `git worktree add` never gets, since only the .d.ts stubs are tracked (.gitignore: "systemOptions/*" +
# "!systemOptions/**/*.d.ts"). Runs on every mwt invocation so older worktrees self-heal.
function wt_ensure_system_options() {
    local WORKTREE_DIR="$1"
    local SENTINEL="systemOptions/allCity.js"

    [[ -e "$WORKTREE_DIR/$SENTINEL" ]] && return 0

    if [[ -e "$MOP_MONOREPO_PATH/$SENTINEL" ]]; then
        echo "Cloning systemOptions/ from main checkout…"
        rm -rf "$WORKTREE_DIR/systemOptions"
        cp -c -R "$MOP_MONOREPO_PATH/systemOptions" "$WORKTREE_DIR/systemOptions"
        # Restore the tracked .d.ts stubs to this branch's version; the wholesale copy clobbered them with main's.
        git -C "$WORKTREE_DIR" checkout -- systemOptions 2>/dev/null
        return 0
    fi

    # Main checkout never ran download-options either: fetch fresh. Needs VPN (internal *.local API hosts) and
    # $GETDATATOKEN (read by ~/.zshrc, handed to yarn alone since it isn't exported). Never blocks worktree
    # creation: mwt's point is not needing VPN, so a missing/failed fetch warns and continues.
    if ! scutil --nc list | command grep -q "Connected"; then
        echo "Warning: systemOptions/ is missing and VPN is off — skipping (some option/enum dropdowns may not work). Connect to VPN and re-run mwt to heal."
        return 0
    fi

    echo "Fetching systemOptions/ via yarn download-options (requires VPN)…"
    (cd "$WORKTREE_DIR" && GETDATATOKEN="$GETDATATOKEN" yarn download-options) || \
        echo "Warning: yarn download-options failed. Some option/enum dropdowns may not work."
}

TICKET_NUMBER="${1:-}"
if [[ -z "$TICKET_NUMBER" ]]; then
    echo "Usage: mwt [-n|--new-window] [--no-pr] <MOP-XXXX>"
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

# Sibling file (not inside the worktree, so it never shows in its `git status`) that
# tmux-restore-ticket-titles.sh reads to re-tag @ticket_title after a tmux-resurrect restore. Written on every
# run, so older worktrees self-heal.
echo "$TICKET_TITLE" > "${WORKTREE_DIR}.title"

if [[ -e "$WORKTREE_DIR" ]]; then
    echo "Worktree already exists at $WORKTREE_DIR — opening it."
    wt_install_hooks "$WORKTREE_DIR"
    wt_link_claude_local "$MOP_MONOREPO_PATH" "$WORKTREE_DIR"
    wt_ensure_system_options "$WORKTREE_DIR"
    cd "$WORKTREE_DIR" && zsh ~/bin/tmux-dev-layout.sh "${DEV_LAYOUT_FLAGS[@]}"
    exit 0
fi

# Branch plumbing runs from the main checkout via refs only; its HEAD and working tree are never touched.
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
wt_link_claude_local "$MOP_MONOREPO_PATH" "$WORKTREE_DIR"
wt_ensure_system_options "$WORKTREE_DIR"

echo "Worktree ready: $WORKTREE_DIR"
cd "$WORKTREE_DIR" && zsh ~/bin/tmux-dev-layout.sh "${DEV_LAYOUT_FLAGS[@]}"
