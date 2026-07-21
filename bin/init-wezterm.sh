#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"
REPO_ROOT="$(resolve_repo_root "$SCRIPT_DIR")" || exit 1

function install_wezterm() {
    echo ""
    echo "=== WezTerm 設定 ==="
    echo ""

    if ! ensure_brew; then
        echo "尚未安裝 Homebrew。請先執行 init-brew.sh。"
        exit 1
    fi

    if brew list --cask wezterm &>/dev/null; then
        echo "✓ wezterm 已安裝"
    else
        echo "正在安裝 wezterm..."
        brew install --cask wezterm || { echo "安裝 wezterm 失敗。"; exit 1; }
    fi

    stow_pkg wezterm || exit 1

    echo "✓ WezTerm 設定完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_wezterm
fi
