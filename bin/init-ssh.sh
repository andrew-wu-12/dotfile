#!/bin/bash

function setup_ssh_key() {
    echo ""
    echo "=== Git SSH 金鑰設定 ==="
    echo ""
    
    SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
    SSH_CONFIG="$HOME/.ssh/config"
    
    # Ensure .ssh directory exists
    if [ ! -d "$HOME/.ssh" ]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        echo "✓ 已建立 .ssh 目錄"
    fi
    
    # Check if SSH key already exists
    if [ -f "$SSH_KEY_PATH" ]; then
        echo "✓ SSH 金鑰已存在於 $SSH_KEY_PATH"
    else
        echo "找不到 SSH 金鑰，正在產生新的 SSH 金鑰..."
        
        # Get email for SSH key
        read -p "請輸入要用於 SSH 金鑰的電子郵件地址：" email </dev/tty
        
        if [ -z "$email" ]; then
            echo "✗ 產生 SSH 金鑰需要電子郵件地址"
            return 1
        fi
        
        # Generate SSH key
        ssh-keygen -t ed25519 -C "$email" -f "$SSH_KEY_PATH" -N ""
        
        if [ $? -eq 0 ]; then
            echo "✓ SSH 金鑰產生成功"
        else
            echo "✗ SSH 金鑰產生失敗"
            return 1
        fi
    fi
    
    # Start ssh-agent and add key
    echo "正在啟動 ssh-agent 並加入金鑰..."
    eval "$(ssh-agent -s)" > /dev/null 2>&1
    ssh-add --apple-use-keychain "$SSH_KEY_PATH" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✓ SSH 金鑰已加入 ssh-agent"
    fi
    
    # Configure SSH config for automatic keychain usage
    if [ ! -f "$SSH_CONFIG" ] || ! grep -q "UseKeychain yes" "$SSH_CONFIG"; then
        echo "正在設定 SSH config..."
        cat >> "$SSH_CONFIG" << 'EOF'

# SSH Key Configuration for Git
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519

Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
        chmod 600 "$SSH_CONFIG"
        echo "✓ 已更新 SSH config"
    else
        echo "✓ SSH config 已設定完成"
    fi
    
    # Copy public key to clipboard
    if [ -f "$SSH_KEY_PATH.pub" ]; then
        cat "$SSH_KEY_PATH.pub" | pbcopy
        echo ""
        echo "✓ 已將 SSH 公鑰複製到剪貼簿"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "你的 SSH 公鑰："
        cat "$SSH_KEY_PATH.pub"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📝 接下來請："
        echo "1. 前往 GitHub：https://github.com/settings/keys"
        echo "2. 點選「New SSH key」"
        echo "3. 貼上金鑰（已經在你的剪貼簿中）"
        echo "4. 輸入標題後儲存"
        echo "5. 在金鑰列表中點選「Configure SSO」，並針對所屬組織"
        echo "   （例如 morrison-express）點「Authorize」以啟用 SAML SSO"
        echo "   存取，否則無法 clone/push 組織底下的私有 repo"
        echo ""
        read -p "將金鑰加到 GitHub 並完成 SSO 授權後，按 Enter 繼續..." </dev/tty
    fi
    
    # Test SSH connection to GitHub
    echo ""
    echo "正在測試與 GitHub 的 SSH 連線..."
    ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"
    
    if [ $? -eq 0 ]; then
        echo "✓ GitHub SSH 連線成功！"
    else
        echo "⚠️  SSH 連線測試已完成（可能仍需先將金鑰加入 GitHub 才能完成驗證）"
    fi
    
    # Configure git to use SSH instead of HTTPS
    echo ""
    read -r -p "要將 Git 全域設定為使用 SSH 存取 GitHub URL 嗎？[y/N]：" use_ssh_globally </dev/tty
    if [[ "$use_ssh_globally" =~ ^[Yy]$ ]]; then
        git config --global url."git@github.com:".insteadOf "https://github.com/"
        echo "✓ Git 已設定為使用 SSH 存取 GitHub URL"
    else
        echo "已跳過全域 Git SSH 改寫設定"
    fi
    
    echo ""
    echo "✓ SSH 設定完成"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_ssh_key
fi
