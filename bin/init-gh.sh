#!/bin/bash

function setup_github_cli() {
    echo ""
    echo "=== GitHub CLI 驗證 ==="
    echo ""
    
    # Check if already authenticated
    gh auth status 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ GitHub CLI 已完成驗證"
        return 0
    fi
    
    echo "正在使用 SSH 驗證 GitHub CLI..."
    echo ""
    echo "你有兩種方式可選："
    echo "1. 使用瀏覽器驗證（預設）"
    echo "2. 手動貼上驗證 Token"
    echo ""
    read -p "請選擇方式（1 或 2）[1]：" auth_method </dev/tty
    auth_method=${auth_method:-1}
    
    if [ "$auth_method" = "2" ]; then
        # Token-based authentication
        echo ""
        echo "取得 Token 的方式："
        echo "1. 前往：https://github.com/settings/tokens/new"
        echo "2. 設定名稱，並勾選權限範圍：repo、read:org、workflow"
        echo "3. 產生並複製 Token"
        echo ""
        read -p "請貼上你的 GitHub Token：" github_token </dev/tty
        
        if [ -z "$github_token" ]; then
            echo "✗ 未提供 Token"
            return 1
        fi
        
        echo "$github_token" | gh auth login -p ssh -h github.com --with-token
    else
        # Browser-based authentication
        echo "這會開啟瀏覽器進行驗證。"
        echo "⚠️  如果你卡在一次性驗證碼畫面："
        echo "   1. 複製畫面上顯示的代碼"
        echo "   2. 在終端提示中按 Enter"
        echo "   3. 將代碼貼到 GitHub 頁面"
        echo ""
        read -p "按 Enter 繼續..." </dev/tty
        
        # Use SSH protocol for authentication with stdin from terminal
        gh auth login -p ssh -h github.com -w < /dev/tty
    fi
    
    # Verify authentication
    gh auth status 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ GitHub CLI 驗證成功"
        return 0
    else
        echo "✗ GitHub CLI 驗證失敗"
        echo ""
        echo "疑難排解建議："
        echo "1. 確認你已完成瀏覽器驗證"
        echo "2. 嘗試手動執行：gh auth login -p ssh -h github.com -w"
        echo "3. 或使用 Token 方式：gh auth login -p ssh -h github.com --with-token"
        return 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_github_cli
fi
