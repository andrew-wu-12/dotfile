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
        "fzf:fzf"
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

    if ! ensure_pkg_manager; then
        echo "尚未偵測到可用的套件管理工具（Homebrew 或 pacman）。macOS 請先執行 init-brew.sh。"
        exit 1
    fi

    if [ "$(detect_pkg_manager)" = "brew" ]; then
        packages+=("terminal-notifier:terminal-notifier")
    else
        echo "ℹ️  terminal-notifier 是 macOS 專用的通知工具，Arch 上沒有對應套件，已略過。"
    fi

    for package_spec in "${packages[@]}"; do
        local formula="${package_spec%%:*}"
        local command_name="${package_spec##*:}"

        if command -v "$command_name" &>/dev/null; then
            echo "✓ ${formula} 已安裝"
            continue
        fi

        echo "正在安裝 ${formula}..."
        pkg_install "$formula" || { echo "安裝 ${formula} 失敗。"; exit 1; }
    done

    local plugin
    for plugin in "${zsh_plugins[@]}"; do
        if [ -f "$(zsh_plugin_file "$plugin")" ]; then
            echo "✓ ${plugin} 已安裝"
            continue
        fi

        echo "正在安裝 ${plugin}..."
        pkg_install "$plugin" || { echo "安裝 ${plugin} 失敗。"; exit 1; }
    done

    echo "✓ 推薦 CLI 工具安裝完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_recommended_cli_tools
fi
