#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

function install_wezterm() {
    echo ""
    echo "=== WezTerm 設定 ==="
    echo ""

    if ! command -v brew &>/dev/null; then
        echo "尚未安裝 Homebrew。請先安裝 Homebrew：https://brew.sh"
        exit 1
    fi

    if ! command -v stow &>/dev/null; then
        echo "錯誤：找不到 'stow' 指令。請先安裝 GNU Stow。"
        exit 1
    fi

    if brew list --cask wezterm &>/dev/null; then
        echo "✓ wezterm 已安裝"
    else
        echo "正在安裝 wezterm..."
        brew install --cask wezterm || { echo "安裝 wezterm 失敗。"; exit 1; }
    fi

    (
        cd "$REPO_ROOT" || exit 1
        stow --restow wezterm || exit 1
    ) || {
        echo "stow wezterm 設定失敗"
        exit 1
    }

    echo "✓ WezTerm 設定完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_wezterm
fi
