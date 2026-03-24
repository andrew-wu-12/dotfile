#!/bin/bash

function setup_github_cli() {
    echo ""
    echo "=== GitHub CLI Authentication ==="
    echo ""
    
    # Check if already authenticated
    gh auth status 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ GitHub CLI already authenticated"
        return 0
    fi
    
    echo "Authenticating GitHub CLI with SSH..."
    echo ""
    echo "You have two options:"
    echo "1. Browser-based authentication (default)"
    echo "2. Paste authentication token manually"
    echo ""
    read -p "Choose method (1 or 2) [1]: " auth_method </dev/tty
    auth_method=${auth_method:-1}
    
    if [ "$auth_method" = "2" ]; then
        # Token-based authentication
        echo ""
        echo "To get a token:"
        echo "1. Go to: https://github.com/settings/tokens/new"
        echo "2. Give it a name and select scopes: repo, read:org, workflow"
        echo "3. Generate and copy the token"
        echo ""
        read -p "Paste your GitHub token: " github_token </dev/tty
        
        if [ -z "$github_token" ]; then
            echo "✗ No token provided"
            return 1
        fi
        
        echo "$github_token" | gh auth login -p ssh -h github.com --with-token
    else
        # Browser-based authentication
        echo "This will open your browser for authentication."
        echo "⚠️  If you get stuck on the one-time code screen:"
        echo "   1. Copy the code shown"
        echo "   2. Press Enter in the browser prompt"
        echo "   3. Paste the code in the GitHub page"
        echo ""
        read -p "Press Enter to continue..." </dev/tty
        
        # Use SSH protocol for authentication with stdin from terminal
        gh auth login -p ssh -h github.com -w < /dev/tty
    fi
    
    # Verify authentication
    gh auth status 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ GitHub CLI authentication successful"
        return 0
    else
        echo "✗ GitHub CLI authentication failed"
        echo ""
        echo "Troubleshooting tips:"
        echo "1. Make sure you completed the browser authentication"
        echo "2. Try running manually: gh auth login -p ssh -h github.com -w"
        echo "3. Or use token method: gh auth login -p ssh -h github.com --with-token"
        return 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_github_cli
fi
