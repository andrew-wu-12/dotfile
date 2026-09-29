#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"
REPO_ROOT="$(resolve_repo_root "$SCRIPT_DIR")" || exit 1

function install_wezterm() {
    echo ""
    echo "=== WezTerm 設定 ==="
    echo ""

    if ! ensure_pkg_manager; then
        echo "尚未偵測到可用的套件管理工具（Homebrew 或 pacman）。macOS 請先執行 init-brew.sh。"
        exit 1
    fi

    # brew list, not command -v: the cask may not put a wezterm CLI on PATH.
    local installed=1
    case "$(detect_pkg_manager)" in
        brew) brew list --cask wezterm &>/dev/null && installed=0 ;;
        pacman) pacman -Qi wezterm &>/dev/null && installed=0 ;;
    esac

    if [ "$installed" -eq 0 ]; then
        echo "✓ wezterm 已安裝"
    else
        echo "正在安裝 wezterm..."
        # brew installs it as a cask; pacman has it as a regular package in "extra".
        pkg_install wezterm wezterm cask || { echo "安裝 wezterm 失敗。"; exit 1; }
    fi

    stow_pkg wezterm || exit 1

    echo "✓ WezTerm 設定完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_wezterm
fi
