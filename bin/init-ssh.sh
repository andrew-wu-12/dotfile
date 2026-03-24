#!/bin/bash

function setup_ssh_key() {
    echo ""
    echo "=== SSH Key Setup for Git ==="
    echo ""
    
    SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
    SSH_CONFIG="$HOME/.ssh/config"
    
    # Ensure .ssh directory exists
    if [ ! -d "$HOME/.ssh" ]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        echo "✓ Created .ssh directory"
    fi
    
    # Check if SSH key already exists
    if [ -f "$SSH_KEY_PATH" ]; then
        echo "✓ SSH key already exists at $SSH_KEY_PATH"
    else
        echo "No SSH key found. Generating new SSH key..."
        
        # Get email for SSH key
        read -p "Enter your email address for SSH key: " email </dev/tty
        
        if [ -z "$email" ]; then
            echo "✗ Email is required for SSH key generation"
            return 1
        fi
        
        # Generate SSH key
        ssh-keygen -t ed25519 -C "$email" -f "$SSH_KEY_PATH" -N ""
        
        if [ $? -eq 0 ]; then
            echo "✓ SSH key generated successfully"
        else
            echo "✗ Failed to generate SSH key"
            return 1
        fi
    fi
    
    # Start ssh-agent and add key
    echo "Starting ssh-agent and adding key..."
    eval "$(ssh-agent -s)" > /dev/null 2>&1
    ssh-add --apple-use-keychain "$SSH_KEY_PATH" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✓ SSH key added to ssh-agent"
    fi
    
    # Configure SSH config for automatic keychain usage
    if [ ! -f "$SSH_CONFIG" ] || ! grep -q "UseKeychain yes" "$SSH_CONFIG"; then
        echo "Configuring SSH config..."
        cat >> "$SSH_CONFIG" << 'EOF'

# SSH Key Configuration for Git
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519

Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
        chmod 600 "$SSH_CONFIG"
        echo "✓ Updated SSH config"
    else
        echo "✓ SSH config already configured"
    fi
    
    # Copy public key to clipboard
    if [ -f "$SSH_KEY_PATH.pub" ]; then
        cat "$SSH_KEY_PATH.pub" | pbcopy
        echo ""
        echo "✓ Public SSH key copied to clipboard"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Your public key:"
        cat "$SSH_KEY_PATH.pub"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📝 Next steps:"
        echo "1. Go to GitHub: https://github.com/settings/keys"
        echo "2. Click 'New SSH key'"
        echo "3. Paste the key (already in your clipboard)"
        echo "4. Give it a title and save"
        echo ""
        read -p "Press Enter after you've added the key to GitHub..." </dev/tty
    fi
    
    # Test SSH connection to GitHub
    echo ""
    echo "Testing SSH connection to GitHub..."
    ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"
    
    if [ $? -eq 0 ]; then
        echo "✓ SSH connection to GitHub successful!"
    else
        echo "⚠️  SSH connection test completed (authentication may require key to be added to GitHub)"
    fi
    
    # Configure git to use SSH instead of HTTPS
    echo ""
    echo "Configuring git to use SSH for GitHub..."
    git config --global url."git@github.com:".insteadOf "https://github.com/"
    echo "✓ Git configured to use SSH for GitHub URLs"
    
    echo ""
    echo "✓ SSH Setup Complete"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_ssh_key
fi
