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

SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/tmux-deploy-lib.sh"

# Check VPN connection
if ! scutil --nc list | command grep -q "Connected"; then
    echo "Error: VPN connection is off. Please connect to VPN before deploying."
    exit 1
fi

FAILED=0
for JOB in mop_console_monorepo_uat mop_console_monorepo_dev; do
    deploy_trigger_job "$JOB" BRANCH "$1" || FAILED=1
done

if [ "$FAILED" -eq 0 ]; then
    echo "Deploy Success!"
else
    echo "Deploy finished with errors."
    exit 1
fi
