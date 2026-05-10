#!/bin/bash

function install_recommended_cli_tools() {
    local packages=(
        "zoxide:zoxide"
        "ripgrep:rg"
        "eza:eza"
    )

    echo ""
    echo "=== 推薦 CLI 工具 ==="
    echo ""

    if ! command -v brew &>/dev/null; then
        echo "尚未安裝 Homebrew。請先安裝 Homebrew：https://brew.sh"
        exit 1
    fi

    for package_spec in "${packages[@]}"; do
        local formula="${package_spec%%:*}"
        local command_name="${package_spec##*:}"

        if command -v "$command_name" &>/dev/null; then
            echo "✓ $formula 已安裝"
            continue
        fi

        echo "正在安裝 $formula..."
        brew install "$formula" || { echo "安裝 $formula 失敗。"; exit 1; }
    done

    echo "✓ 推薦 CLI 工具安裝完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_recommended_cli_tools
fi
