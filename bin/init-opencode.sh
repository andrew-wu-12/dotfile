#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"
REPO_ROOT="$(resolve_repo_root "$SCRIPT_DIR")" || exit 1

function install_opencode() {
    echo ""
    echo "=== opencode 設定 ==="
    echo ""

    if ! ensure_pkg_manager; then
        echo "尚未偵測到可用的套件管理工具（Homebrew 或 pacman）。macOS 請先執行 init-brew.sh。"
        exit 1
    fi

    if command -v opencode &>/dev/null; then
        echo "✓ opencode 已安裝"
    else
        echo "正在安裝 opencode..."
        # Not in Arch's official repos; opencode-bin is the maintainer-run AUR package.
        pkg_install opencode opencode-bin aur || { echo "安裝 opencode 失敗。"; exit 1; }
    fi

    stow_pkg opencode || exit 1

    echo "✓ opencode 設定完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_opencode
fi
