#!/bin/bash

function install_oh_my_zsh() {
    echo ""
    echo "=== Oh My Zsh Setup Script ==="
    echo ""
    # Check if oh-my-zsh is already installed
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "✓ oh-my-zsh is already installed"
    else
        echo "Cannot find oh-my-zsh, prepare to install..."
        echo "Installing oh-my-zsh..."
        # Use unattended installation to avoid it taking over the terminal
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        
        if [ -d "$HOME/.oh-my-zsh" ]; then
            echo "✓ oh-my-zsh installed successfully"
        else
            echo "✗ Failed to install oh-my-zsh"
        fi
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_oh_my_zsh
fi
