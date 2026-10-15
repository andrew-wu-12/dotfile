#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"
REPO_ROOT="$(resolve_repo_root "$SCRIPT_DIR")" || exit 1
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-claude.sh"

SKILLS_SRC="$REPO_ROOT/claude/.claude/skills"
SKILLS_DEST="$HOME/.claude/skills"

function link_claude_skills() {
    echo ""
    echo "=== Claude Code skills 連結 ==="
    echo ""

    if [ -L "$SKILLS_DEST" ]; then
        if [ "$(cd "$SKILLS_DEST" 2>/dev/null && pwd -P)" = "$(cd "$SKILLS_SRC" && pwd -P)" ]; then
            echo "✓ ~/.claude/skills 已整個連結到此 repo，略過。"
            return 0
        fi
        echo "⚠️  ~/.claude/skills 是指向其他位置的連結（$(readlink "$SKILLS_DEST")），為避免寫入別的 repo，略過。"
        return 1
    fi

    mkdir -p "$SKILLS_DEST" || return 1

    local link
    for link in "$SKILLS_DEST"/*; do
        [ -L "$link" ] || continue
        case "$(readlink "$link")" in
            "$SKILLS_SRC"/*)
                if [ ! -e "$link" ]; then
                    rm "$link"
                    echo "  已移除失效連結：$(basename "$link")"
                fi
                ;;
        esac
    done

    local dir name target linked=0 existing=0 skipped=""
    for dir in "$SKILLS_SRC"/*/; do
        dir="${dir%/}"
        [ -f "$dir/SKILL.md" ] || continue
        name="$(basename "$dir")"
        target="$SKILLS_DEST/$name"
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$dir" ]; then
            existing=$((existing + 1))
        elif [ -e "$target" ] || [ -L "$target" ]; then
            skipped="$skipped $name"
        else
            ln -s "$dir" "$target" || return 1
            linked=$((linked + 1))
        fi
    done

    echo "✓ 新連結 ${linked} 個，已存在 ${existing} 個。"
    if [ -n "$skipped" ]; then
        echo "⚠️  下列 skill 名稱已被你自己的 skill 使用，保留你的版本、未連結："
        for name in $skipped; do
            echo "  • $name"
        done
    fi
    echo "未變更 ~/.claude 下的 settings.json、CLAUDE.md 等個人設定。"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_claude || exit 1
    link_claude_skills
fi
