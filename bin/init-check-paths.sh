#!/bin/bash

if ((BASH_VERSINFO[0] < 4)); then
    echo "錯誤：需要 Bash 4 以上版本。目前版本：$BASH_VERSION"
    exit 1
fi

function check_and_fix_paths() {
    local dotfile_zshrc
    local temp_file

    echo ""
    echo "=== 路徑設定檢查 ==="
    echo ""

    if [ -f "../zsh/.zshrc" ]; then
        dotfile_zshrc="../zsh/.zshrc"
        echo "目前以 dotfiles repo 模式執行，目標檔案：$dotfile_zshrc"
    else
        dotfile_zshrc="$HOME/.zshrc"
        echo "目前以獨立模式執行，目標檔案：$dotfile_zshrc"
    fi

    if [ ! -f "$dotfile_zshrc" ]; then
        echo "正在建立 $dotfile_zshrc..."
        touch "$dotfile_zshrc"
    fi

    declare -A defaults=(
        ["MOP_CONFIGURATION_PATH"]="$HOME/project/mop_configuration_files"
        ["MOP_CONSOLE_PATH"]="$HOME/project/mop_console"
        ["MOP_MONOREPO_PATH"]="$HOME/project/mop-console-monorepo"
        ["MOP_EPOD_PATH"]="$HOME/project/mop_epod"
    )

    echo "全新 Mac 小提示：通常使用 ~/project 底下的預設路徑即可。"

    for var in "${!defaults[@]}"; do
        if ! grep -q "^export $var=" "$dotfile_zshrc"; then
            echo "正在寫入預設的 $var..."
            echo "export $var=\"${defaults[$var]}\"" >> "$dotfile_zshrc"
        fi
    done

    echo ""
    echo "正在檢查專案路徑..."

    for var in MOP_CONFIGURATION_PATH MOP_CONSOLE_PATH MOP_MONOREPO_PATH MOP_EPOD_PATH; do
        local current_path
        local expanded_path
        local answer
        local new_path

        current_path=$(grep -E "^export $var=" "$dotfile_zshrc" | sed -E 's/^export [A-Z_]+="(.*)"$/\1/' | tail -n 1)
        expanded_path="${current_path/\$HOME/$HOME}"

        echo ""
        echo "$var=$current_path"
        if [ -d "$expanded_path" ]; then
            echo "✓ 目錄已存在"
        else
            echo "目錄目前尚不存在。這在新機器上是正常的。"
        fi

        read -r -p "要修改這個路徑嗎？[y/N]：" answer </dev/tty
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            read -r -p "請輸入新路徑（家目錄請使用 \$HOME）：" new_path </dev/tty
            if [ -n "$new_path" ]; then
                temp_file=$(mktemp)
                sed "s|^export $var=.*|export $var=\"$new_path\"|" "$dotfile_zshrc" > "$temp_file"
                mv "$temp_file" "$dotfile_zshrc"
                current_path="$new_path"
                expanded_path="${current_path/\$HOME/$HOME}"
                echo "✓ 已更新 $var"
            fi
        fi

        if [ ! -d "$expanded_path" ]; then
            read -r -p "要現在建立這個目錄嗎？（$expanded_path）[y/N]：" answer </dev/tty
            if [[ "$answer" =~ ^[Yy]$ ]]; then
                mkdir -p "$expanded_path" || { echo "建立 $expanded_path 失敗"; exit 1; }
                echo "✓ 已建立 $expanded_path"
            fi
        fi
    done

    echo ""
    echo "✓ 路徑設定完成"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_and_fix_paths
fi
