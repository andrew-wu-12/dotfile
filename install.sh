#!/bin/bash
set -euo pipefail

REPO_HTTPS="https://github.com/andrew-wu-12/dotfile.git"
REPO_SSH="git@github.com:andrew-wu-12/dotfile.git"
DOTFILE_ROOT="${DOTFILE_ROOT:-$HOME/dotfile}"

function ensure_git() {
    case "$(uname -s)" in
        Darwin)
            if ! xcode-select -p &>/dev/null; then
                echo "需要 Xcode Command Line Tools（提供 git），正在開啟安裝視窗..."
                xcode-select --install || true
                echo "安裝完成後請重新執行此安裝指令。"
                exit 1
            fi
            ;;
        Linux)
            if ! command -v pacman &>/dev/null; then
                echo "錯誤：僅支援 macOS 與 Arch Linux。" >&2
                exit 1
            fi
            command -v git &>/dev/null || sudo pacman -S --needed --noconfirm git
            ;;
        *)
            echo "錯誤：僅支援 macOS 與 Arch Linux。" >&2
            exit 1
            ;;
    esac
}

function fetch_repo() {
    if [ -d "$DOTFILE_ROOT/.git" ]; then
        echo "已存在 $DOTFILE_ROOT，正在更新..."
        git -C "$DOTFILE_ROOT" pull --ff-only || echo "警告：無法 fast-forward，保留現有內容繼續執行。"
    elif [ -e "$DOTFILE_ROOT" ]; then
        echo "錯誤：$DOTFILE_ROOT 已存在但不是 git repo，請移除或設定 DOTFILE_ROOT 指向其他位置。" >&2
        exit 1
    else
        echo "正在複製 dotfile 到 $DOTFILE_ROOT..."
        git clone "$REPO_HTTPS" "$DOTFILE_ROOT"
        git -C "$DOTFILE_ROOT" remote set-url --push origin "$REPO_SSH"
    fi
}

ensure_git
fetch_repo
export DOTFILE_ROOT
exec bash "$DOTFILE_ROOT/bin/init.sh" "$@" </dev/tty
