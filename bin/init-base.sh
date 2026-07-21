#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"
REPO_ROOT="$(resolve_repo_root "$SCRIPT_DIR")" || exit 1

function setup_base_config() {
    echo ""
    echo "=== 基礎設定安裝 ==="
    echo ""

    if ! command -v stow &>/dev/null; then
        echo "錯誤：找不到 'stow' 指令。請先安裝 GNU Stow。"
        exit 1
    fi

    stow_pkg zsh || exit 1
    stow_pkg bin "$HOME/bin" || exit 1

    echo "✓ 基礎設定安裝完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_base_config
fi
