#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"

function install_homebrew() {
    echo ""
    echo "=== Homebrew 安裝 ==="
    echo ""

    # ensure_brew also covers the case where brew is installed but not yet on PATH
    # (a fresh install, or a shell that never ran `brew shellenv`).
    if ensure_brew; then
        echo "✓ Homebrew 已安裝：$(brew --prefix)"
        return 0
    fi

    local answer
    echo "尚未安裝 Homebrew。安裝過程會："
    echo "  • 要求輸入 sudo 密碼"
    echo "  • 一併安裝 Xcode Command Line Tools（數 GB，需要一段時間）"
    read -r -p "現在安裝嗎？[y/N]：" answer </dev/tty
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "已略過。請手動安裝後重新執行：https://brew.sh"
        return 1
    fi

    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        || { echo "❌ Homebrew 安裝失敗。"; return 1; }

    if ! ensure_brew; then
        echo "❌ 安裝後仍在 /opt/homebrew 找不到 brew。請重新開啟終端機後再試一次。"
        return 1
    fi

    echo "✓ Homebrew 安裝完成：$(brew --prefix)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_homebrew
fi
