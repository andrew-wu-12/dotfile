#!/bin/bash
# init-workspace.sh — create .workspace.conf stubs for workspace directories
#
# Usage:
#   init-workspace.sh                        — interactive: prompt for workspace path (default ~/project)
#   init-workspace.sh --default-path <path>  — interactive: prompt with a custom default path; no ~/personal auto-write
#   init-workspace.sh --isMOP <path>         — non-interactive: write MOP config at <path>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"

MOP_MODE=0
MOP_PATH=""
DEFAULT_WS_PATH="$HOME/project"
SKIP_PERSONAL=0

case "${1:-}" in
    --isMOP)
        MOP_MODE=1
        MOP_PATH="${2:-}"
        if [ -z "$MOP_PATH" ]; then
            echo "init-workspace.sh --isMOP: path argument required"
            exit 1
        fi
        ;;
    --default-path)
        DEFAULT_WS_PATH="${2:-}"
        if [ -z "$DEFAULT_WS_PATH" ]; then
            echo "init-workspace.sh --default-path: path argument required"
            exit 1
        fi
        DEFAULT_WS_PATH="${DEFAULT_WS_PATH/#\~/$HOME}"
        SKIP_PERSONAL=1
        ;;
    "")
        ;;
    *)
        echo "Usage: init-workspace.sh [--isMOP <path> | --default-path <path>]"
        exit 1
        ;;
esac

write_stub() {
    local dir="$1" kind="$2"
    local config="$dir/.workspace.conf"
    if [ -f "$config" ]; then
        echo "✓ 已存在，跳過：$config"
        return 0
    fi
    mkdir -p "$dir"
    case "$kind" in
        mop)
            cat > "$config" <<'EOF'
WORKSPACE_PREVIEW_CMD="$HOME/bin/tmux-ticket-status.sh"
WORKSPACE_SERVE_CMD="yarn serve"
WORKSPACE_SERVE_LABEL="mop-console-monorepo"
WORKSPACE_SERVE_PORT=4200
WORKSPACE_BUILD_CONF=1
EOF
            ;;
        *)
            printf 'NOTE_PATH=""\n' > "$config"
            ;;
    esac
    echo "✓ 已建立：$config"
}

if [ "$MOP_MODE" -eq 1 ]; then
    write_stub "$MOP_PATH" mop
    exit 0
fi

echo ""
echo "=== Workspace 設定 ==="
echo ""

printf "工作 Workspace 路徑 [%s]: " "${DEFAULT_WS_PATH/#$HOME/\~}"
read -r ws_input </dev/tty
if [ -z "$ws_input" ]; then
    ws_path="$DEFAULT_WS_PATH"
else
    ws_path="${ws_input/#\~/$HOME}"
fi

write_stub "$ws_path" general

if [ "$SKIP_PERSONAL" -eq 0 ]; then
    personal_path="$HOME/personal"
    if [ -d "$personal_path" ]; then
        write_stub "$personal_path" general
    else
        echo "(~/personal 目錄不存在，跳過個人 workspace 設定)"
    fi
fi

echo ""
echo "✓ Workspace 設定完成"
