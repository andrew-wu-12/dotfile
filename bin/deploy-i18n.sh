#!/bin/bash
# Required parameters
# @raycast.schemaVersion 1
# @raycast.title Deploy I18n
# @raycast.mode compact
# @raycast.packageName Deploy I18n V1

# Optional parameters
# @raycast.icon 🚀
# @raycast.argument1 { "type": "dropdown", "placeholder": "Env", "optional": false, "data": [{"title": "DEV", "value": "dev"},{"title": "UAT", "value": "uat"}, { "title": "PROD", "value": "prod" }] }

echo "Target ENV : $1"

JOB_NAME="mop_console_i18n_with_version"

curl https://jenkins.morrison.express/job/"$JOB_NAME"/buildWithParameters \
--user $JENKINS_TOKEN \
--data I18n_ENV="$1" \

echo "Deploy Success!"
