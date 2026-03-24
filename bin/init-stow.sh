#!/bin/bash

function stow_config() {
    echo ""
    echo "=== Stowing Configuration ==="
    echo ""
    
    # Save current directory
    CURRENT_DIR=$(pwd)
    
    cd ..
    stow zsh
    
    #check if $HOME/bin exists, if not create it
    if [ ! -d "$HOME/bin" ]; then
        mkdir "$HOME/bin"
        echo "Created $HOME/bin directory"
    fi
    stow --target=$HOME/bin bin
    stow nvim-stow
    stow opencode
    stow tmux
    stow starship
    stow wezterm
    
    # Return to original directory
    cd "$CURRENT_DIR"
    
    echo "✓ Stowing complete"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    stow_config
fi
