#!/bin/zsh

function get_from_json() {
    echo $1 | jq $2 | tr -d '"'
}

function pr_get_content() {
    local TICKET_NUMBER="$1"
    echo "Related Tickets: https://morrisonexpress.atlassian.net/browse/${TICKET_NUMBER}"
}

function get_ticket_summary() {
    local TICKET_NUMBER=$1
    
    local RESPONSE=$(curl -s  \
        -u "$JIRA_TOKEN" \
        -X GET \
        -H "Content-Type: application/json" \
    https://morrisonexpress.atlassian.net/rest/api/3/issue/"$TICKET_NUMBER"/?fields=parent%2Cpriority%2Ccomponents%2Cissuetype%2Ccustomfield_10006%2Csummary&fieldsByKeys=false)
    
    echo $(get_from_json "$RESPONSE" ".fields.summary")
}

TICKET_NUMBER=$1
TICKET_SUMMARY=$(get_ticket_summary $TICKET_NUMBER)
echo "$TICKET_SUMMARY"
source ~/.zshrc
ENV_LIST=("dev" "uat" "prod")
cd $MOP_CONFIGURATION_PATH
git add .;git stash -m 'config stash'

for CURRENT_ENV in "${ENV_LIST[@]}"; do
    FINAL_BRANCH=""
    if [ "$CURRENT_ENV" == "prod" ]; then
        FINAL_BRANCH="master"
    else
        FINAL_BRANCH=$CURRENT_ENV
    fi
    ENV_NAME=$(echo $CURRENT_ENV | tr 'a-z' 'A-Z')
    TARGET_BRANCH="feature/$TICKET_NUMBER-$CURRENT_ENV"
    PR_TITLE="[$ENV_NAME] $TICKET_NUMBER: $TICKET_SUMMARY"
    PR_CONTENT=$(pr_get_content $TICKET_NUMBER)
    git checkout "$FINAL_BRANCH"
    git pull
    if git show-ref --verify --quiet refs/heads/$TARGET_BRANCH; then
        echo "Branch $TARGET_BRANCH already exists. Skipping branch creation and pr creation."
        git checkout "$TARGET_BRANCH"
    else
        git checkout -b "$TARGET_BRANCH"
    fi
    git stash apply stash@{0}
    git add .
    git commit -m 'feature: adjust configuration'
    git push origin "$TARGET_BRANCH"
    gh pr create -a @me -B $FINAL_BRANCH -t "$PR_TITLE" -b "$PR_CONTENT" -d
done

