#!/bin/bash
# Required parameters
# @raycast.schemaVersion 1
# @raycast.title Deploy One
# @raycast.mode fullOutput
#
# @raycast.icon 🚀
# @raycast.packageName Deploy One
# @raycast.argument1 {"type": "text", "placeholder": "Branch Name" }

JOB_NAMES=("mop_console_monorepo_uat" "mop_console_monorepo_dev")
for JOB in "${JOB_NAMES[@]}"; do
    echo "Processing Jenkins Job: $JOB"
    curl https://jenkins.morrison.express/job/"$JOB"/buildWithParameters \
    --user "$JENKINS_TOKEN" \
    --data BRANCH="$1"
done

echo "Deploy Success!"
