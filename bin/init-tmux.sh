#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"
REPO_ROOT="$(resolve_repo_root "$SCRIPT_DIR")" || exit 1

function install_tmux() {
    echo ""
    echo "=== Tmux 設定 ==="
    echo ""

    if ! ensure_brew; then
        echo "尚未安裝 Homebrew。請先執行 init-brew.sh。"
        exit 1
    fi

    if command -v tmux &>/dev/null; then
        echo "✓ tmux 已安裝"
    else
        echo "正在安裝 tmux..."
        brew install tmux || { echo "安裝 tmux 失敗。"; exit 1; }
    fi

    stow_pkg tmux || exit 1
    if command -v tmux &>/dev/null; then
        echo "正在安裝 tmux 套件..."
        tmux source ~/.tmux.conf
    fi

    echo "✓ Tmux 設定完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_tmux
fi
