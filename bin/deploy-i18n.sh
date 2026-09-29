#!/bin/zsh
# Required parameters
# @raycast.schemaVersion 1
# @raycast.title JENKINS: Deploy I18n
# @raycast.mode fullOutput
# @raycast.packageName Deploy I18n

# Optional parameters
# @raycast.icon 🚀
# @raycast.argument1 { "type": "dropdown", "placeholder": "Env", "optional": false, "data": [{"title": "DEV", "value": "dev"},{"title": "UAT", "value": "uat"}, { "title": "PROD", "value": "prod" }] }

emulate -L zsh

source ~/.zshrc

SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/tmux-deploy-lib.sh"

if ! scutil --nc list | command grep -q "Connected"; then
    echo "Error: VPN connection is off. Please connect to VPN before deploying."
    exit 1
fi

echo "Target ENV : $1"

JOB_NAME="mop_console_i18n_with_version"

deploy_trigger_job "$JOB_NAME" I18N_ENV "$1" || exit 1

echo "Deploy Success!"
