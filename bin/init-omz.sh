#!/bin/bash

function install_oh_my_zsh() {
    echo ""
    echo "=== Oh My Zsh 設定腳本 ==="
    echo ""
    # Check if oh-my-zsh is already installed
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "✓ oh-my-zsh 已安裝"
    else
        echo "找不到 oh-my-zsh，準備安裝..."
        echo "正在安裝 oh-my-zsh..."
        # Use unattended installation to avoid it taking over the terminal
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        
        if [ -d "$HOME/.oh-my-zsh" ]; then
            echo "✓ oh-my-zsh 安裝成功"
        else
            echo "✗ oh-my-zsh 安裝失敗"
        fi
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_oh_my_zsh
fi
