#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"

REPO_ROOT=$(resolve_repo_root "$SCRIPT_DIR") || exit 1

EXTENSIONS=(
    "dbaeumer.vscode-eslint"
    "esbenp.prettier-vscode"
    "stylelint.vscode-stylelint"
    "ms-python.python"
    "ms-toolsai.jupyter"
    "ritwickdey.liveserver"
    "pflannery.vscode-versionlens"
)

function install_vscode() {
    echo ""
    echo "=== VS Code 安裝 ==="
    echo ""

    case "$(detect_pkg_manager)" in
        brew)   pkg_install visual-studio-code "" cask ;;
        pacman) pkg_install visual-studio-code "visual-studio-code-bin" aur ;;
        *)      echo "錯誤：找不到支援的套件管理工具" >&2; return 1 ;;
    esac

    if ! command -v code &>/dev/null; then
        echo "✗ VS Code 安裝失敗：找不到 'code' 指令"
        return 1
    fi
    echo "✓ VS Code 安裝完成"

    echo ""
    echo "正在安裝擴充功能..."
    local ext
    for ext in "${EXTENSIONS[@]}"; do
        echo "  → $ext"
        code --install-extension "$ext" --force 2>/dev/null
    done
    echo "✓ 擴充功能安裝完成"

    echo ""
    echo "正在連結設定檔..."
    local settings_src="$REPO_ROOT/vscode-stow/Library/Application Support/Code/User/settings.json"
    case "$(detect_pkg_manager)" in
        brew)
            local user_dir="$HOME/Library/Application Support/Code/User"
            mkdir -p "$user_dir"
            stow_pkg vscode-stow "$HOME"
            ;;
        pacman)
            local user_dir="$HOME/.config/Code/User"
            mkdir -p "$user_dir"
            ln -sf "$settings_src" "$user_dir/settings.json"
            ;;
    esac
    echo "✓ 設定檔已連結"
}

install_vscode
