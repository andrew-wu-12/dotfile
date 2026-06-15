#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

function setup_base_config() {
    echo ""
    echo "=== 基礎設定安裝 ==="
    echo ""

    if ! command -v stow &>/dev/null; then
        echo "錯誤：找不到 'stow' 指令。請先安裝 GNU Stow。"
        exit 1
    fi

    if [ ! -d "$HOME/bin" ]; then
        mkdir -p "$HOME/bin" || { echo "建立 $HOME/bin 失敗"; exit 1; }
        echo "已建立 $HOME/bin 目錄"
    fi

    (
        cd "$REPO_ROOT" || exit 1
        stow --adopt --restow zsh || exit 1
        stow --restow --target="$HOME/bin" bin || exit 1
    ) || {
        echo "stow 基礎設定失敗"
        exit 1
    }

    echo "✓ 基礎設定安裝完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_base_config
fi
