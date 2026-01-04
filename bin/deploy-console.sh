#!/bin/bash -l
# Required parameters
# @raycast.schemaVersion 1
# @raycast.title Deploy Console
# @raycast.packageName Deploy Console
# @raycast.mode fullOutput
#
# Optional parameters
# @raycast.icon 🚀
# @raycast.argument1 {"type": "text", "placeholder": "Branch Name" }
# @raycast.argument2 {"type": "dropdown", "optional": true, "placeholder": "Override Env", "data": [{ "title": "FEATURE", "value": "feature" }, { "title": "UAT", "value": "uat" } ] }

function get_job_name() {
    local TICKET_ENV=$1
    
    if [ "$TICKET_ENV" == "feature" ]; then
        echo "mop_console_bulild_by_feature"
    else
        echo "mop_console_bulild_by_epic_or_hotfix"
    fi
}

function get_final_env() {
    local CURRENT_ENV=$1
    local OVERRIDE_ENV=$2
    if [ -n "$OVERRIDE_ENV"]; then
        echo $CURRENT_ENV
    else
        echo $OVERRIDE_ENV
    fi
}

function create_branch() {
    local TARGET_BRANCH=$1
    cd $MOP_CONFIGURATION_PATH
    git co master
    if git show-ref --verify --quiet refs/heads/$TARGET_BRANCH; then
        git checkout "$TARGET_BRANCH"
    else
        git checkout -b "$TARGET_BRANCH"
    fi
    git push origin "$TARGET_BRANCH"
}
source ~/zshrc

IFS="/" read -ra arr <<< "$1"
IFS="-" read -ra ticket <<< "$1"

TARGET_BRANCH="$1"
OVERRIDE_ENV="$2"

FINAL_ENV=$(get_final_env "${arr[0]}" $OVERRIDE_ENV)
FINAL_BRANCH="$FINAL_ENV/MOP-${ticket[1]}"
JOB_NAME=$(get_job_name $FINAL_ENV)

echo "Target Branch : $FINAL_BRANCH
Target Env : $FINAL_ENV
Processing Jenkins Job: $JOB_NAME
JENKINS_TOKEN: $JENKINS_TOKEN"

create_branch $FINAL_BRANCH
curl https://jenkins.morrison.express/job/"$JOB_NAME"/buildWithParameters \
    --user $JENKINS_TOKEN \
    --data CORE_BRANCH="$FINAL_BRANCH" \
    --data SUBMODULE=core \
    --data EPIC_TYPE="$FINAL_ENV" \
    --data JIRA_TICKET_TYPE=MOP \
    --data JIRA_TICKET_NUMBER="${ticket[1]}";

echo "Deploy Success!"
