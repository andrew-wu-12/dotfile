#!/bin/zsh
# Required parameters
# @raycast.schemaVersion 1
# @raycast.title Deploy One
# @raycast.mode fullOutput
#
# @raycast.icon 🚀
# @raycast.packageName Deploy One
# @raycast.argument1 {"type": "text", "placeholder": "Branch Name" }

# Start with clean zsh environment
emulate -L zsh

# Source zshrc to get environment variables
source ~/.zshrc

# Check VPN connection
if ! scutil --nc list | command grep -q "Connected"; then
    echo "Error: VPN connection is off. Please connect to VPN before deploying."
    exit 1
fi

JOB_NAMES=("mop_console_monorepo_uat" "mop_console_monorepo_dev")
for JOB in "${JOB_NAMES[@]}"; do
    echo "Processing Jenkins Job: $JOB"
    curl "https://jenkins.morrison.express/job/$JOB/buildWithParameters" \
    --user "$JENKINS_TOKEN" \
    --data BRANCH="$1"
done

echo "Deploy Success!"
