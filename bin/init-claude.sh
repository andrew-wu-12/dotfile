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

# stow_pkg backs up pre-existing real files (runtime-generated settings.json, skill dirs) rather than deleting them.
    stow_pkg claude || return 1

    echo "✓ Claude 設定連結完成"
}

function ignore_claude_local_settings() {
    echo ""
    echo "=== 全域忽略 .claude/settings.local.json ==="
    echo ""

    local pattern='**/.claude/settings.local.json'
    local file
    file="$(git config --global --type=path core.excludesFile 2>/dev/null)"
    file="${file:-${XDG_CONFIG_HOME:-$HOME/.config}/git/ignore}"

    if [ -f "$file" ] && grep -qxF "$pattern" "$file"; then
        echo "✓ 已存在於 ${file}，略過。"
        return 0
    fi

    mkdir -p "$(dirname "$file")" || return 1
    if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then
        echo "" >> "$file"
    fi
    echo "$pattern" >> "$file" || return 1
    echo "✓ 已加入 ${file}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_claude
    stow_claude_config
    ignore_claude_local_settings
fi
