#!/bin/bash

# Configuration
packages=("jq" "gh" "curl" "git" "stow" "nvm" "zoxide" "nvim" "tmux")

function install_package() {
    echo ""
    echo "=== Package Install Script ==="
    echo ""
    for pkg in "${packages[@]}"; do
        # Special handling for nvm since it's a shell function, not a binary
        if [ "$pkg" = "nvm" ]; then
            # Source nvm if it exists
            if [ -s "$HOME/.nvm/nvm.sh" ]; then
                source "$HOME/.nvm/nvm.sh"
            fi
            
            # Check if nvm is now available as a function
            if ! type nvm &> /dev/null; then
                echo "Cannot find package: $pkg, prepare to install..."
                echo "Installing nvm..."
                curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
                # Source nvm after installation
                export NVM_DIR="$HOME/.nvm"
                [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
            else
                echo "✓ nvm is already installed"
            fi
        else
            # Regular package check
            if ! command -v $pkg &> /dev/null; then
                echo "Cannot find package: $pkg, prepare to install..."
                brew install $pkg -y
            else
                echo "✓ $pkg is already installed"
            fi
        fi
    done
    echo "✓ package install complete"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_package
fi
