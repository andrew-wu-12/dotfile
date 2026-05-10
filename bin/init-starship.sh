#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

function install_starship() {
    echo ""
    echo "=== Starship 設定 ==="
    echo ""

    if ! command -v brew &>/dev/null; then
        echo "尚未安裝 Homebrew。請先安裝 Homebrew：https://brew.sh"
        exit 1
    fi

    if ! command -v stow &>/dev/null; then
        echo "錯誤：找不到 'stow' 指令。請先安裝 GNU Stow。"
        exit 1
    fi

    if command -v starship &>/dev/null; then
        echo "✓ starship 已安裝"
    else
        echo "正在安裝 starship..."
        brew install starship || { echo "安裝 starship 失敗。"; exit 1; }
    fi

    (
        cd "$REPO_ROOT" || exit 1
        stow --restow starship || exit 1
    ) || {
        echo "stow starship 設定失敗"
        exit 1
    }

    echo "✓ Starship 設定完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_starship
fi
