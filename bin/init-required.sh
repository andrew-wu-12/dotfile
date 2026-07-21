#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"

function install_required_packages() {
    local packages=("jq" "gh" "curl" "git" "stow")

    echo ""
    echo "=== 必要套件安裝 ==="
    echo ""
    if ! ensure_brew; then
        echo "尚未安裝 Homebrew。請先執行 init-brew.sh。"
        exit 1
    fi

    echo "正在更新 Homebrew..."
    brew update || { echo "更新 Homebrew 失敗，請檢查網路或環境設定。"; exit 1; }

    for pkg in "${packages[@]}"; do
        if command -v "$pkg" &>/dev/null; then
            echo "✓ $pkg 已安裝"
            continue
        fi

        echo "正在安裝 $pkg..."
        brew install "$pkg" || { echo "安裝 $pkg 失敗。"; exit 1; }
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
