#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"

function install_workmux() {
    echo ""
    echo "=== workmux 設定 ==="
    echo ""

    if ! ensure_pkg_manager; then
        echo "尚未偵測到可用的套件管理工具（Homebrew 或 pacman）。macOS 請先執行 init-brew.sh。"
        exit 1
    fi

    if command -v workmux &>/dev/null; then
        echo "✓ workmux 已安裝"
    elif [ "$(detect_pkg_manager)" = "brew" ]; then
        echo "正在安裝 workmux..."
        brew install raine/workmux/workmux || { echo "安裝 workmux 失敗。"; exit 1; }
    else
        echo "workmux 沒有 pacman / AUR 套件，請改用：cargo install workmux"
        exit 1
    fi

    local config="$HOME/.config/workmux/config.yaml"
    if [ -e "$config" ]; then
        echo "✓ 保留既有設定：$config"
    else
        mkdir -p "$(dirname "$config")"
        printf 'status_format: false\n' > "$config"
        echo "✓ 已建立 ${config}（status_format: false，不改動 tmux 視窗列）"
    fi

    if ! command -v claude &>/dev/null; then
        echo "未偵測到 Claude Code，略過 workmux-status 外掛。"
    elif grep -q '"workmux-status@workmux"' "$HOME/.claude/settings.json" 2>/dev/null; then
        echo "✓ workmux-status 外掛已安裝"
    else
        claude plugin marketplace add raine/workmux || { echo "新增 workmux marketplace 失敗。"; exit 1; }
        claude plugin install workmux-status || { echo "安裝 workmux-status 外掛失敗。"; exit 1; }
    fi

    echo "✓ workmux 設定完成。新開的 claude 會回報狀態，執行 workmux dashboard 查看。"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_workmux
fi
