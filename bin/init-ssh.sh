#!/bin/bash

function sanitize_identity_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}

function backup_key_pair() {
    local key_path="$1"
    local ts
    ts=$(date +%Y%m%d%H%M%S)
    mv "$key_path" "$key_path.bak.$ts"
    [ -f "$key_path.pub" ] && mv "$key_path.pub" "$key_path.pub.bak.$ts"
    echo "✓ 已備份舊金鑰為 $key_path.bak.$ts"
}

function generate_ssh_key() {
    local key_path="$1"
    local email

    read -p "請輸入要用於 SSH 金鑰的電子郵件地址：" email </dev/tty

    if [ -z "$email" ]; then
        echo "✗ 產生 SSH 金鑰需要電子郵件地址"
        return 1
    fi

    ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N ""

    if [ $? -eq 0 ]; then
        echo "✓ SSH 金鑰產生成功"
    else
        echo "✗ SSH 金鑰產生失敗"
        return 1
    fi
}

function add_key_to_agent() {
    local key_path="$1"

    echo "正在啟動 ssh-agent 並加入金鑰..."
    eval "$(ssh-agent -s)" > /dev/null 2>&1
    ssh-add --apple-use-keychain "$key_path" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "✓ SSH 金鑰已加入 ssh-agent"
    fi
}

function configure_default_ssh_config() {
    if [ ! -f "$SSH_CONFIG" ] || ! grep -q "UseKeychain yes" "$SSH_CONFIG"; then
        echo "正在設定 SSH config..."
        cat >> "$SSH_CONFIG" << 'EOF'

# SSH Key Configuration for Git
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519

Host * !github-*
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
        chmod 600 "$SSH_CONFIG"
        echo "✓ 已更新 SSH config"
    else
        echo "✓ SSH config 已設定完成"
    fi
}

function publish_public_key() {
    local key_path="$1"

    if [ -f "$key_path.pub" ]; then
        cat "$key_path.pub" | pbcopy
        echo ""
        echo "✓ 已將 SSH 公鑰複製到剪貼簿"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "你的 SSH 公鑰："
        cat "$key_path.pub"
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
}

function test_github_connection() {
    local key_path="$1"

    echo ""
    echo "正在測試與 GitHub 的 SSH 連線..."
    if [ -n "$key_path" ]; then
        # -F /dev/null: ignore ~/.ssh/config entirely. Host github.com there sets
        # IdentityFile ~/.ssh/id_ed25519, and IdentitiesOnly=yes alone does not
        # exclude that — it only excludes extra ssh-agent-offered keys — so
        # without -F this test silently falls back to the default key.
        ssh -F /dev/null -i "$key_path" -o IdentitiesOnly=yes -T git@github.com 2>&1 | grep -q "successfully authenticated"
    else
        ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"
    fi

    if [ $? -eq 0 ]; then
        echo "✓ GitHub SSH 連線成功！"
    else
        echo "⚠️  SSH 連線測試已完成（可能仍需先將金鑰加入 GitHub 才能完成驗證）"
    fi
}

function prompt_global_ssh_rewrite() {
    echo ""
    echo "⚠️  這是全域設定，會套用到這台機器上所有的 git repo，不論該 repo 使用哪一個"
    echo "   SSH 身分或設定。套用後，https://github.com/ 的網址一律會被改寫成 SSH"
    echo "   網址；日後若該次 SSH 連線失敗（例如金鑰尚未加到 GitHub、金鑰被移除、"
    echo "   身分設定有誤等），git 不會自動退回改用 HTTPS，而是直接回報失敗"
    echo "   （fatal: Could not read from remote repository）。"
    read -r -p "要將 Git 全域設定為使用 SSH 存取 GitHub URL 嗎？[y/N]：" use_ssh_globally </dev/tty
    if [[ "$use_ssh_globally" =~ ^[Yy]$ ]]; then
        git config --global url."git@github.com:".insteadOf "https://github.com/"
        echo "✓ Git 已設定為使用 SSH 存取 GitHub URL"
    else
        echo "已跳過全域 Git SSH 改寫設定"
    fi
}

function run_default_key_tail() {
    local key_path="$1"

    add_key_to_agent "$key_path"
    configure_default_ssh_config
    publish_public_key "$key_path"
    test_github_connection
    prompt_global_ssh_rewrite

    echo ""
    echo "✓ SSH 設定完成"
}

# Sets up an SSH key scoped to a single workspace directory: the key lives at
# ~/.ssh/id_ed25519_<name>, and git only picks it up for repos under that
# directory via `includeIf "gitdir:...` + `core.sshCommand` — so it never
# touches ~/.ssh/config or the default identity.
function setup_workspace_identity() {
    local workspace_path abs_workspace name key_path gitconfig_snippet
    local create_new continue_choice

    echo ""
    read -r -p "請輸入要套用獨立 SSH 身分的工作目錄路徑：" workspace_path </dev/tty

    if [ -z "$workspace_path" ]; then
        echo "✗ 需要輸入工作目錄路徑"
        return 1
    fi

    workspace_path="${workspace_path/#\~/$HOME}"

    if [ ! -d "$workspace_path" ]; then
        mkdir -p "$workspace_path" || { echo "✗ 無法建立工作目錄 $workspace_path"; return 1; }
        echo "✓ 已建立工作目錄 $workspace_path"
    fi

    abs_workspace="$(cd "$workspace_path" && pwd)"
    name="$(sanitize_identity_name "$(basename "$abs_workspace")")"

    if [ -z "$name" ]; then
        echo "✗ 無法從資料夾名稱產生識別名稱"
        return 1
    fi

    key_path="$HOME/.ssh/id_ed25519_$name"
    gitconfig_snippet="$HOME/.gitconfig-$name"

    if [ -f "$key_path" ]; then
        echo "✓ [$name] 的 SSH 金鑰已存在於 $key_path"
        read -r -p "要建立新的 SSH 金鑰嗎？[y/N]：" create_new </dev/tty
        if [[ "$create_new" =~ ^[Yy]$ ]]; then
            backup_key_pair "$key_path"
            generate_ssh_key "$key_path" || return 1
        else
            read -r -p "要繼續執行其餘設定，還是要略過？[continue/skip]：" continue_choice </dev/tty
            if [[ ! "$continue_choice" =~ ^[Cc] ]]; then
                echo "已略過 [$name] 的 SSH 設定"
                return 0
            fi
        fi
    else
        generate_ssh_key "$key_path" || return 1
    fi

    add_key_to_agent "$key_path"

    # -F /dev/null: ignore ~/.ssh/config entirely. Its Host github.com block sets
    # IdentityFile ~/.ssh/id_ed25519, which IdentitiesOnly=yes does NOT exclude —
    # config-file IdentityFile entries count as "explicit" just like -i does — so
    # without -F, ssh offers the default key first and GitHub silently
    # authenticates as the wrong identity instead of this workspace's key.
    cat > "$gitconfig_snippet" << EOF
[core]
    sshCommand = "ssh -F /dev/null -i $key_path -o IdentitiesOnly=yes"
EOF
    echo "✓ 已寫入 $gitconfig_snippet"

    if ! grep -qF "gitdir:$abs_workspace/" "$HOME/.gitconfig" 2>/dev/null; then
        {
            echo ""
            echo "[includeIf \"gitdir:$abs_workspace/\"]"
            echo "    path = $gitconfig_snippet"
        } >> "$HOME/.gitconfig"
        echo "✓ 已在 ~/.gitconfig 加入 $abs_workspace/ 的獨立設定"
    else
        echo "✓ ~/.gitconfig 已包含 $abs_workspace/ 的獨立設定"
    fi

    publish_public_key "$key_path"
    test_github_connection "$key_path"
    prompt_global_ssh_rewrite

    echo ""
    echo "✓ [$name] 工作目錄的 SSH 設定完成"
}

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

    if [ -f "$SSH_KEY_PATH" ]; then
        echo "✓ SSH 金鑰已存在於 $SSH_KEY_PATH"

        local create_new continue_choice
        read -r -p "要建立新的 SSH 金鑰嗎？[y/N]：" create_new </dev/tty
        if [[ "$create_new" =~ ^[Yy]$ ]]; then
            setup_workspace_identity
            return $?
        fi

        read -r -p "要繼續執行其餘設定，還是要略過？[continue/skip]：" continue_choice </dev/tty
        if [[ ! "$continue_choice" =~ ^[Cc] ]]; then
            echo "已略過 SSH 設定"
            return 0
        fi
    else
        echo "找不到 SSH 金鑰，正在產生新的 SSH 金鑰..."
        generate_ssh_key "$SSH_KEY_PATH" || return 1
    fi

    run_default_key_tail "$SSH_KEY_PATH"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_ssh_key
fi
