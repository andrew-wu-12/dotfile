#!/bin/zsh
# Open the [DEV] config PR (feature/MOP-XXXX -> dev) for mop_configuration_files.
#
# Migrated from the old 3-branch version that opened dev/uat/master PRs at once:
# promotion to uat and master is a timing judgment call, so this now stops at dev
# and you promote by hand. Run AFTER editing the config working tree (e.g. via the
# privilege-node skill); this stashes those edits and lays them on a fresh
# feature branch off an up-to-date dev.

source ~/.zshrc

function get_from_json() { echo $1 | jq $2 | tr -d '"'; }

function get_ticket_summary() {
    local TICKET_NUMBER=$1
    local RESPONSE=$(curl -s -u "$JIRA_TOKEN" -X GET -H "Content-Type: application/json" \
      "https://morrisonexpress.atlassian.net/rest/api/3/issue/${TICKET_NUMBER}/?fields=summary&fieldsByKeys=false")
    echo $(get_from_json "$RESPONSE" ".fields.summary")
}

TICKET_NUMBER=$1
if [[ -z "$TICKET_NUMBER" ]]; then
    echo "Usage: checkout-config.sh <MOP-XXXX>"
    exit 1
fi

cd $MOP_CONFIGURATION_PATH || { echo "Error: MOP_CONFIGURATION_PATH not found."; exit 1; }

# There must be working-tree changes to deploy, or there is no PR to open.
if git diff --quiet && git diff --cached --quiet; then
    echo "Error: no changes in $MOP_CONFIGURATION_PATH to deploy."
    echo "Edit the config (e.g. privileges.json) first, then re-run."
    exit 1
fi

TICKET_SUMMARY=$(get_ticket_summary $TICKET_NUMBER)
echo "Ticket: $TICKET_NUMBER — $TICKET_SUMMARY"

TARGET_BRANCH="feature/$TICKET_NUMBER"
PR_TITLE="[DEV] $TICKET_NUMBER: $TICKET_SUMMARY"
PR_CONTENT="Related Tickets: https://morrisonexpress.atlassian.net/browse/${TICKET_NUMBER}"

# Preserve the working edits, then base a clean feature branch on latest dev.
git add .
git stash push -m "config-$TICKET_NUMBER"

git checkout dev
git pull

if git show-ref --verify --quiet refs/heads/$TARGET_BRANCH; then
    echo "Branch $TARGET_BRANCH already exists; reusing it."
    git checkout "$TARGET_BRANCH"
else
    git checkout -b "$TARGET_BRANCH"
fi

git stash apply
git add .
git commit -m "feature($TICKET_NUMBER): adjust configuration"
git push origin "$TARGET_BRANCH"
gh pr create -a @me -B dev -t "$PR_TITLE" -b "$PR_CONTENT" -d
git stash drop
