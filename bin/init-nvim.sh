#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

function install_nvim() {
    echo ""
    echo "=== Nvim 設定 ==="
    echo ""

    if ! command -v brew &>/dev/null; then
        echo "尚未安裝 Homebrew。請先安裝 Homebrew：https://brew.sh"
        exit 1
    fi

    if ! command -v stow &>/dev/null; then
        echo "錯誤：找不到 'stow' 指令。請先安裝 GNU Stow。"
        exit 1
    fi

    if command -v nvim &>/dev/null; then
        echo "✓ nvim 已安裝"
    else
        echo "正在安裝 nvim..."
        brew install nvim || { echo "安裝 nvim 失敗。"; exit 1; }
    fi

    (
        cd "$REPO_ROOT" || exit 1
        stow --restow nvim-stow || exit 1
    ) || {
        echo "stow nvim 設定失敗"
        exit 1
    }

    echo "✓ Nvim 設定完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_nvim
fi
