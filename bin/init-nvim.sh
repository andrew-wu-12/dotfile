#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"
REPO_ROOT="$(resolve_repo_root "$SCRIPT_DIR")" || exit 1

function install_nvim() {
    echo ""
    echo "=== Nvim 設定 ==="
    echo ""

    if ! ensure_pkg_manager; then
        echo "尚未偵測到可用的套件管理工具（Homebrew 或 pacman）。macOS 請先執行 init-brew.sh。"
        exit 1
    fi

    if command -v nvim &>/dev/null; then
        echo "✓ nvim 已安裝"
    else
        echo "正在安裝 nvim..."
        # brew calls the formula "nvim"; pacman calls the package "neovim".
        pkg_install nvim neovim || { echo "安裝 nvim 失敗。"; exit 1; }
    fi

    stow_pkg nvim-stow || exit 1

    echo "✓ Nvim 設定完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_nvim
fi
