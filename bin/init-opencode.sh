#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

function install_opencode() {
    echo ""
    echo "=== opencode 設定 ==="
    echo ""

    if ! command -v brew &>/dev/null; then
        echo "尚未安裝 Homebrew。請先安裝 Homebrew：https://brew.sh"
        exit 1
    fi

    if ! command -v stow &>/dev/null; then
        echo "錯誤：找不到 'stow' 指令。請先安裝 GNU Stow。"
        exit 1
    fi

    if command -v opencode &>/dev/null; then
        echo "✓ opencode 已安裝"
    else
        echo "正在安裝 opencode..."
        brew install opencode || { echo "安裝 opencode 失敗。"; exit 1; }
    fi

    (
        cd "$REPO_ROOT" || exit 1
        stow --restow opencode || exit 1
    ) || {
        echo "stow opencode 設定失敗"
        exit 1
    }

    echo "✓ opencode 設定完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_opencode
fi
