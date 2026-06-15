#!/bin/bash

if ((BASH_VERSINFO[0] < 4)); then
    echo "你的 Bash 版本 ($BASH_VERSION) 過舊。正在升級到 Bash 4+..."

    if ! command -v brew &>/dev/null; then
        echo "尚未安裝 Homebrew。請先安裝 Homebrew：https://brew.sh"
        exit 1
    fi

    brew install bash || { echo "安裝 Bash 失敗，請檢查 Homebrew 設定。"; exit 1; }

    NEW_BASH_PATH="$(brew --prefix)/bin/bash"
    if [ ! -x "$NEW_BASH_PATH" ]; then
        echo "錯誤：在 $NEW_BASH_PATH 找不到新安裝的 Bash 執行檔。"
        exit 1
    fi

    echo "正在使用升級後的 Bash 重新執行 init-required.sh..."
    exec "$NEW_BASH_PATH" "$0"
fi

if ((BASH_VERSINFO[0] < 4)); then
    echo "錯誤：需要 Bash 4+。目前偵測到的版本：$BASH_VERSION"
    echo "提示：可使用 Homebrew 安裝相容版本的 Bash：brew install bash"
    exit 1
fi

function install_required_packages() {
    local packages=("jq" "gh" "curl" "git" "stow")

    echo ""
    echo "=== 必要套件安裝 ==="
    echo ""
    echo "這個步驟在全新 Mac 上可能會安裝較新的 Bash 或 Homebrew 依賴。"

    if ! command -v brew &>/dev/null; then
        echo "尚未安裝 Homebrew。請先安裝 Homebrew：https://brew.sh"
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
