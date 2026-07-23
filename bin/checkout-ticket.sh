#!/bin/zsh
# Required parameters
# @raycast.schemaVersion 1
# @raycast.title Check Out Ticket
# @raycast.mode fullOutput
# @raycast.packageName Check Out Ticket
# @raycast.icon 🚀
#
# Optional parameters
# @raycast.argument1 {"type": "text", "placeholder": "DEV Ticket Number" }

# Start with clean zsh environment
emulate -L zsh

# Shared JIRA/PR helpers (get_from_json, pr_get_params/content/title,
# get_ticket_content/parent). ${0:A:h} is the symlink-resolved dir of this
# script, so this works when invoked through the ~/bin symlink.
source "${0:A:h}/ticket-lib.sh"

function pr_push_branch() {
    local BRANCH_DATA=$(pr_get_params "$1" "$2" "$3")
    local CURRENT_BRANCH_NAME=$(get_from_json "$BRANCH_DATA" ".branch_name")
    local BASE_BRANCH_NAME=$(get_from_json "$BRANCH_DATA" ".base_name")
    local PR_TITLE=$(pr_get_title "$BRANCH_DATA")
    local PR_CONTENT=$(pr_get_content "$BRANCH_DATA")
    
    git fetch
    git checkout $BASE_BRANCH_NAME
    git pull origin $BASE_BRANCH_NAME
    
    if git show-ref --verify --quiet refs/heads/$CURRENT_BRANCH_NAME; then
        echo "Branch $CURRENT_BRANCH_NAME already exists. Skipping branch creation and pr creation."
        git checkout $CURRENT_BRANCH_NAME
    else
        git checkout -b $CURRENT_BRANCH_NAME
        git commit --allow-empty -m "Initial draft for branch $CURRENT_BRANCH_NAME"
        git push origin $CURRENT_BRANCH_NAME
        gh pr create -a @me -B $BASE_BRANCH_NAME -t "$PR_TITLE" -b "$PR_CONTENT" -d
    fi
}

# Source zshrc after function definitions to avoid alias conflicts
source ~/.zshrc

# Check VPN connection
if ! scutil --nc list | command grep -q "Connected"; then
    echo "Error: VPN connection is off. Please connect to VPN before deploying."
    exit 1
fi


TICKET_NUMBER="$1"
TICKET_DATA=$(get_ticket_content "$TICKET_NUMBER")
TICKET_ISSUE_TYPE=$(get_from_json "$TICKET_DATA" ".issue_type")
PARENT_DATA=$(get_ticket_parent "$TICKET_DATA")
PARENT_TICKET_NUMBER=$(get_from_json "$PARENT_DATA" ".ticket_number")
echo "TICKET_NUMBER: $TICKET_NUMBER
TICKET_ISSUE_TYPE: $TICKET_ISSUE_TYPE
PARENT_TICKET_NUMBER: $PARENT_TICKET_NUMBER
PARENT_DATA: $PARENT_DATA"
cd $MOP_MONOREPO_PATH
git add .;git stash -m 'STASH CURRENT CHANGES'
if [[ "$TICKET_ISSUE_TYPE" == "Production Support" ]]; then
    pr_push_branch "$TICKET_DATA" main hotfix
else
    UAT_BRANCH_NAME="uat/$PARENT_TICKET_NUMBER"
    pr_push_branch "$PARENT_DATA" main uat
    pr_push_branch "$TICKET_DATA" $UAT_BRANCH_NAME feature
fi
