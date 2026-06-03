#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

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

    if ! command -v stow &>/dev/null; then
        echo "錯誤：找不到 'stow' 指令。請先安裝 GNU Stow。"
        return 1
    fi

    # Remove existing settings.json — it contains only runtime noise, not real config.
    # The repo version starts clean so real settings accumulate there over time.
    if [ -f "$HOME/.claude/settings.json" ] && [ ! -L "$HOME/.claude/settings.json" ]; then
        rm "$HOME/.claude/settings.json"
        echo "✓ 已移除舊有 settings.json（runtime 資料）"
    fi

    # For each skill tracked in the repo, remove the real dir at the stow target if
    # it exists so that stow can replace it with a symlink.
    local skills_repo="$REPO_ROOT/claude/.claude/skills"
    if [ -d "$skills_repo" ]; then
        for skill_path in "$skills_repo"/*/; do
            [ -d "$skill_path" ] || continue
            local skill_name
            skill_name=$(basename "${skill_path%/}")
            local target="$HOME/.claude/skills/$skill_name"
            if [ -d "$target" ] && [ ! -L "$target" ]; then
                rm -rf "$target"
                echo "✓ 已移除舊有 skills/$skill_name（將由 stow 連結）"
            fi
        done
    fi

    (
        cd "$REPO_ROOT" || exit 1
        stow --restow --target="$HOME" claude || exit 1
    ) || {
        echo "❌ Claude 設定連結失敗"
        return 1
    }

    echo "✓ Claude 設定連結完成"
}

install_claude
stow_claude_config
