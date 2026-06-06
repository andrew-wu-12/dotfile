#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

function install_tmux() {
    echo ""
    echo "=== Tmux 設定 ==="
    echo ""

    if ! command -v brew &>/dev/null; then
        echo "尚未安裝 Homebrew。請先安裝 Homebrew：https://brew.sh"
        exit 1
    fi

    if ! command -v stow &>/dev/null; then
        echo "錯誤：找不到 'stow' 指令。請先安裝 GNU Stow。"
        exit 1
    fi

    if command -v tmux &>/dev/null; then
        echo "✓ tmux 已安裝"
    else
        echo "正在安裝 tmux..."
        brew install tmux || { echo "安裝 tmux 失敗。"; exit 1; }
    fi

    (
        cd "$REPO_ROOT" || exit 1
        stow --restow tmux || exit 1
    ) || {
        echo "stow tmux 設定失敗"
        exit 1
    }
    if command -v tmux &>/dev/null; then
        echo "正在安裝 tmux 套件..."
        tmux source ~/.tmux.conf
    fi

    echo "✓ Tmux 設定完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_tmux
fi
