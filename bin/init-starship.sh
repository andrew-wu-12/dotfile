#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"
REPO_ROOT="$(resolve_repo_root "$SCRIPT_DIR")" || exit 1

function install_starship() {
    echo ""
    echo "=== Starship 設定 ==="
    echo ""

    if ! ensure_pkg_manager; then
        echo "尚未偵測到可用的套件管理工具（Homebrew 或 pacman）。macOS 請先執行 init-brew.sh。"
        exit 1
    fi

    if command -v starship &>/dev/null; then
        echo "✓ starship 已安裝"
    else
        echo "正在安裝 starship..."
        pkg_install starship || { echo "安裝 starship 失敗。"; exit 1; }
    fi

    stow_pkg starship || exit 1

    echo "✓ Starship 設定完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_starship
fi
