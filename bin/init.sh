#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function run_step() {
    local script_name="$1"
    local script_path="$SCRIPT_DIR/$script_name"
    
    echo ""
    echo "正在執行 $script_name..."
    
    if [ ! -x "$script_path" ]; then
        echo "→ $script_name 尚未設定為可執行，正在執行 chmod +x..."
        chmod +x "$script_path"
    fi
    
    "$script_path"
    local result=$?
    
    if [ $result -ne 0 ]; then
        echo "⚠️  警告：$script_name 執行失敗，結束代碼為 $result。"
    else
        echo "✓ $script_name 執行成功。"
    fi
    
    return $result
}

function ask_yes_no() {
    local prompt="$1"
    local answer
    
    read -r -p "$prompt" answer </dev/tty
    [[ "$answer" =~ ^[Yy]$ ]]
}

function print_preflight_summary() {
    echo ""
    echo "=== 初始化總覽 ==="
    echo ""
    echo "必要套件：jq、gh、curl、git、stow、nvm"
    echo "可選套件：推薦 CLI 工具、Starship、opencode、Nvim、Tmux、WezTerm"
    echo "共用設定：zsh 與 ~/bin 會固定使用 stow 連結"
    echo "後續步驟會詢問專案路徑、憑證、SSH 設定與 GitHub 驗證"
    echo "全新 Mac 小提示：通常保留 ~/project 底下的預設專案路徑即可"
    echo ""
}

print_preflight_summary

# 1. Install Dependencies
run_step "init-required.sh"

# 2. Install Oh My Zsh
run_step "init-omz.sh"

# 3. Stow Shared Configurations
run_step "init-base.sh"

echo ""
echo "=== 可選工具 ==="
echo "直接按 Enter 可跳過任何可選項目。"

if ask_yes_no "要安裝推薦 CLI 工具嗎？（zoxide、ripgrep、eza）[y/N]："; then
    run_step "init-recommend-cli-tools.sh"
fi

if ask_yes_no "要安裝 Starship 嗎？（Shell 提示主題）[y/N]："; then
    run_step "init-starship.sh"
fi

if ask_yes_no "要安裝 opencode 嗎？（CLI + 設定檔）[y/N]："; then
    run_step "init-opencode.sh"
fi

if ask_yes_no "要安裝 Nvim 嗎？（編輯器 + 設定檔）[y/N]："; then
    run_step "init-nvim.sh"
fi

if ask_yes_no "要安裝 Tmux 嗎？（終端多工工具 + 設定檔）[y/N]："; then
    run_step "init-tmux.sh"
fi

if ask_yes_no "要安裝 WezTerm 嗎？（終端機設定）[y/N]："; then
    run_step "init-wezterm.sh"
fi

if ask_yes_no "要安裝 Claude Code 嗎？（CLI + 設定檔）[y/N]："; then
    run_step "init-claude.sh"
fi

# 4. Check and Fix Paths (Edits .zshrc)
run_step "init-check-paths.sh"

# 5. Load Environment Variables (To make MOP_*_PATH available for next steps)
# We replicate the logic here because sourcing a new .zshrc inside a script is tricky
echo ""
echo "=== 載入環境變數 ==="
if [ -f "$HOME/.zshrc" ]; then
    # Extract and evaluate only MOP_*_PATH exports
    while IFS= read -r line; do
        if [[ $line =~ ^export[[:space:]]+(MOP[A-Z_]*PATH)= ]]; then
            eval "$line"
            echo "✓ 已載入：${BASH_REMATCH[1]}"
        fi
    done < <(grep -E "^export MOP[A-Z_]*PATH=" "$HOME/.zshrc")
else
    echo "⚠️  警告：找不到 ~/.zshrc"
fi

# 6. Setup Credentials (Keychain)
run_step "init-credentials.sh"

# 7. Reload Environment Variables (To capture any credential-related env vars if they were exported, though keychain usage avoids this)
# The credentials script stores in keychain, and .zshrc (stowed) has the `security find-generic-password` commands.
# We need to eval those commands to get the tokens into THIS shell session for the clone step (if it needs them, though clone mostly needs gh auth).
# Actually, checkout-ticket needs JIRA_TOKEN, but init.sh mostly needs GH auth.
# Let's just source the specific credential exports from .zshrc if they exist
if [ -f "$HOME/.zshrc" ]; then
    while IFS= read -r line; do
        if [[ $line =~ ^export[[:space:]]+(JENKINS_TOKEN|JIRA_TOKEN|GETDATATOKEN)= ]]; then
            # This is tricky because the line contains $(security ...), so eval is needed
            eval "$line"
        fi
    done < <(grep -E "^export (JENKINS_TOKEN|JIRA_TOKEN|GETDATATOKEN)=" "$HOME/.zshrc")
fi


# 8. Setup SSH
run_step "init-ssh.sh"

# 9. Setup GitHub CLI
run_step "init-gh.sh"

# 10. Clone Repositories
run_step "init-clone.sh"

echo ""
echo "=== 初始化完成 ==="
echo "請重新啟動 shell，或執行 'source ~/.zshrc' 套用所有變更。"
