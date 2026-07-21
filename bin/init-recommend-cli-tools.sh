#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"

function install_recommended_cli_tools() {
    local packages=(
        "zoxide:zoxide"
        "ripgrep:rg"
        "eza:eza"
        "lazygit:lazygit"
    )
    # zsh plugins provide no command of their own, so they are detected by the
    # file .zshrc sources rather than by command -v.
    local zsh_plugins=(
        "zsh-autosuggestions"
        "zsh-syntax-highlighting"
    )

    echo ""
    echo "=== 推薦 CLI 工具 ==="
    echo ""

    if ! ensure_brew; then
        echo "尚未安裝 Homebrew。請先執行 init-brew.sh。"
        exit 1
    fi

    for package_spec in "${packages[@]}"; do
        local formula="${package_spec%%:*}"
        local command_name="${package_spec##*:}"

        if command -v "$command_name" &>/dev/null; then
            echo "✓ ${formula} 已安裝"
            continue
        fi

        echo "正在安裝 ${formula}..."
        brew install "$formula" || { echo "安裝 ${formula} 失敗。"; exit 1; }
    done

    local plugin
    for plugin in "${zsh_plugins[@]}"; do
        if [ -f "/opt/homebrew/share/$plugin/$plugin.zsh" ]; then
            echo "✓ ${plugin} 已安裝"
            continue
        fi

        echo "正在安裝 ${plugin}..."
        brew install "$plugin" || { echo "安裝 ${plugin} 失敗。"; exit 1; }
    done

    echo "✓ 推薦 CLI 工具安裝完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_recommended_cli_tools
fi
