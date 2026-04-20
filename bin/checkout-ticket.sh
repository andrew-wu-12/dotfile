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

function get_from_json() {
    printf '%s\n' "$1" | jq -r $2
}

function pr_get_params() {
    local TICKET_DATA="$1"
    local BASE_NAME="$2"
    local ENV="$3"
    
    local TICKET_NUMBER=$(get_from_json "$TICKET_DATA" ".ticket_number")
    local TICKET=("${(@s/-/)TICKET_NUMBER}")
    local BRANCH_NAME="$ENV/$TICKET_NUMBER"
    local BASE_BRANCH_NAME="$BASE_NAME"
    local TICKET_ID=${TICKET[2]}
    local PREFIX=""
    local ENV_NAME=""
    
    if [[ "$ENV" == "feature" ]]; then
        PREFIX="UAT"
        ENV_NAME="dev"
        elif [[ "$ENV" == "uat" ]]; then
        PREFIX="PROD"
        ENV_NAME="uat"
    else
        PREFIX="HOTFIX"
        ENV_NAME="uat"
    fi
    
    printf '%s\n' "$TICKET_DATA" | jq --arg branch "$BRANCH_NAME" --arg base "$BASE_BRANCH_NAME" --arg env "$ENV_NAME" --arg tid "$TICKET_ID" --arg prefix "$PREFIX" '{ "branch_name": $branch, "base_name": $base, "env_name": $env, "ticket_id": $tid, "ticket_number": .ticket_number, "prefix": $prefix, "summary": .summary}'
}

function pr_get_content() {
    local BRANCH_DATA="$1"
    local ENV_NAME=$(get_from_json "$BRANCH_DATA" ".env_name")
    local TICKET_NUMBER=$(get_from_json "$BRANCH_DATA" ".ticket_number")
    local TICKET_ID=$(get_from_json "$BRANCH_DATA" ".ticket_id")
    echo "### References
Related Tickets: https://morrisonexpress.atlassian.net/browse/${TICKET_NUMBER}
Feature Link: https://mop-${TICKET_ID}.$ENV_NAME.morrison.express/
### Screenshot
### Release Date
### Quality Checklist
- [ ] 所有 CI Checks 均已通過
- [ ] 逐項檢視 AI Review 建議，確認必要修改皆已完成
- [ ] Preview URL 可正確呈現本次功能之內容，並可正常操作；若無法提供 URL，則需附上相關截圖
- [ ] 完整自我審視所有改動內容，能清楚說明每項邏輯與修改原因
- [ ] 程式碼遵循 .github/coding-rules/ 內所定義之團隊規範；若有例外，得於 PR 中註明原因
- [ ] 程式碼遵循 TS Coding rules"
}

function pr_get_title() {
    local BRANCH_DATA="$1"
    local TICKET_NUMBER=$(get_from_json "$BRANCH_DATA" ".ticket_number")
    local PREFIX=$(get_from_json "$BRANCH_DATA" ".prefix")
    local SUMMARY=$(get_from_json "$BRANCH_DATA" ".summary")
    echo "[$PREFIX] $TICKET_NUMBER: $SUMMARY"
}
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

function get_ticket_content() {
    local TICKET_NUMBER="$1"
    
    local RESPONSE=$(curl -s  \
        -u "$JIRA_TOKEN" \
        -X GET \
        -H "Content-Type: application/json" \
    "https://morrisonexpress.atlassian.net/rest/api/3/issue/${TICKET_NUMBER}/?fields=parent%2Cpriority%2Ccomponents%2Cissuetype%2Ccustomfield_10006%2Csummary&fieldsByKeys=false")
    
    local PARENT=$(printf '%s\n' "$RESPONSE" | jq -r '.fields.parent.key // "null"')
    if [[ "$PARENT" == "MOP-24745" ]]; then
        PARENT="null"
    fi
    printf '%s\n' "$RESPONSE" | jq --arg ticket "$TICKET_NUMBER" --arg parent "$PARENT" '{"ticket_number": $ticket, "parent": $parent, "issue_type": .fields.issuetype.name, "priority": .fields.priority.name, "summary": .fields.summary}'
}
function get_ticket_parent() {
    local CURRENT_DATA=$1
    local CURRENT_PARENT_NUMBER=$(get_from_json "$CURRENT_DATA" ".parent")
    
    if [[ "$CURRENT_PARENT_NUMBER" == "null" ]]; then
        echo "$CURRENT_DATA"
    else
        local PARENT_DATA=$(get_ticket_content "$CURRENT_PARENT_NUMBER")
        echo $(get_ticket_parent "$PARENT_DATA")
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
