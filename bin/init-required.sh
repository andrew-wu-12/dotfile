#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"

function install_required_packages() {
    # "<brew/command name>:<pacman name>" — pacman name defaults to the first
    # field when omitted (see the parse below). gh is the one divergence: its
    # command and brew formula are "gh", but the pacman package is "github-cli".
    local packages=("jq" "gh:github-cli" "curl" "git" "stow")

    echo ""
    echo "=== 必要套件安裝 ==="
    echo ""
    if ! ensure_pkg_manager; then
        echo "尚未偵測到可用的套件管理工具（Homebrew 或 pacman）。macOS 請先執行 init-brew.sh。"
        exit 1
    fi

    case "$(detect_pkg_manager)" in
        brew)
            echo "正在更新 Homebrew..."
            brew update || { echo "更新 Homebrew 失敗，請檢查網路或環境設定。"; exit 1; }
            ;;
        pacman)
            echo "正在更新 pacman 套件資料庫..."
            sudo pacman -Sy || { echo "更新 pacman 失敗，請檢查網路或環境設定。"; exit 1; }
            ;;
    esac

    for package_spec in "${packages[@]}"; do
        local pkg="${package_spec%%:*}" pacman_name="${package_spec#*:}"

        if command -v "$pkg" &>/dev/null; then
            echo "✓ $pkg 已安裝"
            continue
        fi

        echo "正在安裝 $pkg..."
        pkg_install "$pkg" "$pacman_name" || { echo "安裝 $pkg 失敗。"; exit 1; }
    done

    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        export NVM_DIR="$HOME/.nvm"
        # shellcheck disable=SC1090
        source "$NVM_DIR/nvm.sh"
    fi

    if type nvm &>/dev/null; then
        echo "✓ nvm 已安裝"
    else
        echo "正在安裝 nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash || { echo "安裝 nvm 失敗。"; exit 1; }
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
        type nvm &>/dev/null || { echo "安裝後載入 nvm 失敗。"; exit 1; }
        echo "✓ nvm 安裝成功"
    fi

    echo "✓ 必要套件安裝完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_required_packages
fi
