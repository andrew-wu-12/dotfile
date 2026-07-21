#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"
REPO_ROOT="$(resolve_repo_root "$SCRIPT_DIR")" || exit 1

function install_claude() {
    echo ""
    echo "=== Claude Code 安裝 ==="
    echo ""

    if command -v claude &>/dev/null; then
        echo "✓ Claude Code 已安裝：$(claude --version 2>/dev/null)"
        return 0
    fi

    echo "正在安裝 Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash -s stable

    if ! command -v claude &>/dev/null; then
        echo "❌ Claude Code 安裝失敗"
        return 1
    fi
    echo "✓ Claude Code 安裝成功"
}

function stow_claude_config() {
    echo ""
    echo "=== Claude 設定連結 ==="
    echo ""

    # Pre-existing real files/dirs (a runtime-generated settings.json, skill dirs
    # Claude Code created itself) are surfaced by stow_pkg, which backs them up
    # rather than deleting them.
    stow_pkg claude || return 1

    echo "✓ Claude 設定連結完成"
}

install_claude
stow_claude_config
