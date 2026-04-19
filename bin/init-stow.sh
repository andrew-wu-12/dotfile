#!/bin/bash

function stow_config() {
    echo ""
    echo "=== Stowing Configuration ==="
    echo ""

    # Ensure the stow command is available
    if ! command -v stow &>/dev/null; then
        echo "Error: 'stow' command not found. Please install GNU Stow."
        exit 1
    fi

    # Save current directory
    CURRENT_DIR=$(pwd)

    # Navigate to parent directory (assumes init-stow.sh resides in bin/)
    cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" || { echo "Failed to change directory."; exit 1; }

    # Stow configurations
    stow zsh || { echo "Failed to stow zsh"; exit 1; }

    # Ensure $HOME/bin exists
    if [ ! -d "$HOME/bin" ]; then
        mkdir "$HOME/bin" || { echo "Failed to create $HOME/bin"; exit 1; }
        echo "Created $HOME/bin directory"
    fi

    stow --target=$HOME/bin bin || { echo "Failed to stow bin"; exit 1; }
    stow nvim-stow || { echo "Failed to stow nvim-stow"; exit 1; }
    stow opencode || { echo "Failed to stow opencode"; exit 1; }
    stow tmux || { echo "Failed to stow tmux"; exit 1; }
    stow starship || { echo "Failed to stow starship"; exit 1; }
    stow wezterm || { echo "Failed to stow wezterm"; exit 1; }

    # Return to original directory
    cd "$CURRENT_DIR" || { echo "Failed to return to original directory"; exit 1; }

    echo "✓ Stowing complete"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    stow_config
fi