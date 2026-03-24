#!/bin/bash

# Source all modular scripts
# This allows access to functions if needed, though most scripts self-execute if called directly.
# However, for init.sh, we want to control the flow and share variables.

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Helper to run a script and handle errors
function run_step() {
    local script_name="$1"
    echo "Running $script_name..."
    "$SCRIPT_DIR/$script_name"
    if [ $? -ne 0 ]; then
        echo "⚠️  Warning: $script_name completed with errors or was skipped."
    fi
}

# 1. Install Dependencies
run_step "init-packages.sh"

# 2. Install Oh My Zsh
run_step "init-omz.sh"

# 3. Stow Configurations
run_step "init-stow.sh"

# 4. Check and Fix Paths (Edits .zshrc)
run_step "init-check-paths.sh"

# 5. Load Environment Variables (To make MOP_*_PATH available for next steps)
# We replicate the logic here because sourcing a new .zshrc inside a script is tricky
echo ""
echo "=== Loading Environment Variables ==="
if [ -f "$HOME/.zshrc" ]; then
    # Extract and evaluate only MOP_*_PATH exports
    while IFS= read -r line; do
        if [[ $line =~ ^export[[:space:]]+(MOP[A-Z_]*PATH)= ]]; then
            eval "$line"
            echo "✓ Loaded: ${BASH_REMATCH[1]}"
        fi
    done < <(grep -E "^export MOP[A-Z_]*PATH=" "$HOME/.zshrc")
else
    echo "⚠️  Warning: ~/.zshrc not found"
fi

# 6. Setup Credentials (Keychain)
run_step "init-credentials.sh"

# 7. Reload Environment Variables (To capture any credential-related env vars if they were exported, though keychain usage avoids this)
# The credentials script stores in keychain, and .zshrc (stowed) has the `security find-generic-password` commands.
# We need to eval those commands to get the tokens into THIS shell session for the clone step (if it needs them, though clone mostly needs gh auth).
# Actually, checkout-ticket needs JIRA_TOKEN, but init.sh mostly needs GH auth.
# Let's just source the specific credential exports from .zshrc if they exist
if [ -f "$HOME/.zshrc" ]; then
     while IFS= read -r line; do
        if [[ $line =~ ^export[[:space:]]+(JENKINS_TOKEN|JIRA_TOKEN|GETDATATOKEN)= ]]; then
            # This is tricky because the line contains $(security ...), so eval is needed
            eval "$line"
        fi
    done < <(grep -E "^export (JENKINS_TOKEN|JIRA_TOKEN|GETDATATOKEN)=" "$HOME/.zshrc")
fi


# 8. Setup SSH
run_step "init-ssh.sh"

# 9. Setup GitHub CLI
run_step "init-gh.sh"

# 10. Clone Repositories
run_step "init-clone.sh"

echo ""
echo "=== Initialization Complete ==="
echo "Please restart your shell or run 'source ~/.zshrc' to apply all changes."
