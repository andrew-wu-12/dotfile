#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"

# Ordered step table as three parallel indexed arrays (kept index-aligned so this
# runs under macOS's stock Bash 3.2 — nothing here needs a newer Bash).
# STEP_KEYS[i] is the detect_status key, STEP_LABELS[i] its Traditional Chinese
# label, STEP_SCRIPTS[i] the sub-script. Order mirrors the safe install sequence.
STEP_KEYS=(brew required omz base recommend-cli starship opencode nvim tmux wezterm claude check-paths credentials ssh gh clone)
STEP_LABELS=(
    "Homebrew"
    "必要套件（jq、gh、curl、git、stow、nvm）"
    "Oh My Zsh"
    "基礎設定（stow zsh + bin）"
    "推薦 CLI 工具（zoxide、rg、eza、lazygit）"
    "Starship 提示主題"
    "opencode"
    "Nvim 編輯器"
    "Tmux"
    "WezTerm"
    "Claude Code"
    "專案路徑設定"
    "憑證（Keychain）"
    "SSH 金鑰"
    "GitHub CLI 驗證"
    "複製專案儲存庫"
)
STEP_SCRIPTS=(
    "init-brew.sh"
    "init-required.sh"
    "init-omz.sh"
    "init-base.sh"
    "init-recommend-cli-tools.sh"
    "init-starship.sh"
    "init-opencode.sh"
    "init-nvim.sh"
    "init-tmux.sh"
    "init-wezterm.sh"
    "init-claude.sh"
    "init-check-paths.sh"
    "init-credentials.sh"
    "init-ssh.sh"
    "init-gh.sh"
    "init-clone.sh"
)

# Core steps for the minimal install (skips the optional editor/terminal/CLI tools).
MINIMAL_KEYS=(brew required omz base check-paths credentials ssh gh clone)

# Steps that must run every time regardless of detect_status. Restowing is
# idempotent and cheap, and skipping it is how ~/bin silently drifts from the repo
# whenever a new script is added.
ALWAYS_RUN_KEYS=(base)

function is_always_run() {
    local key
    for key in "${ALWAYS_RUN_KEYS[@]}"; do
        [ "$key" = "$1" ] && return 0
    done
    return 1
}

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
        echo "⚠️  警告：${script_name} 執行失敗，結束代碼為 ${result}。"
    else
        echo "✓ $script_name 執行成功。"
    fi

    return $result
}

# Load MOP_*_PATH and token exports from ~/.zshrc into this shell so that steps
# like clone/credentials have them available regardless of run order.
function load_env_vars() {
    echo ""
    echo "=== 載入環境變數 ==="
    if [ ! -f "$HOME/.zshrc" ]; then
        echo "⚠️  警告：找不到 ~/.zshrc"
        return
    fi

    while IFS= read -r line; do
        if [[ $line =~ ^export[[:space:]]+(MOP[A-Z_]*PATH)= ]]; then
            eval "$line"
            echo "✓ 已載入：${BASH_REMATCH[1]}"
        fi
    done < <(grep -E "^export MOP[A-Z_]*PATH=" "$HOME/.zshrc")

    while IFS= read -r line; do
        if [[ $line =~ ^export[[:space:]]+(JENKINS_TOKEN|JIRA_TOKEN|GETDATATOKEN)= ]]; then
            eval "$line"
        fi
    done < <(grep -E "^export (JENKINS_TOKEN|JIRA_TOKEN|GETDATATOKEN)=" "$HOME/.zshrc")
}

# Returns 0 when the component for <key> is fully installed/configured.
function detect_status() {
    local key="$1"
    case "$key" in
        brew)
            ensure_brew || return 1
            ;;
        required)
            local pkg
            for pkg in jq gh curl git stow; do
                command -v "$pkg" &>/dev/null || return 1
            done
            ( [ -s "$HOME/.nvm/nvm.sh" ] && export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" && type nvm &>/dev/null ) || return 1
            ;;
        omz)
            [ -d "$HOME/.oh-my-zsh" ] || return 1
            ;;
        base)
            [ -L "$HOME/.zshrc" ] || return 1
            ;;
        recommend-cli)
            local cmd plugin
            for cmd in zoxide rg eza lazygit; do
                command -v "$cmd" &>/dev/null || return 1
            done
            for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
                [ -f "/opt/homebrew/share/$plugin/$plugin.zsh" ] || return 1
            done
            ;;
        starship)
            command -v starship &>/dev/null && [ -L "$HOME/.config/starship.toml" ] || return 1
            ;;
        opencode)
            command -v opencode &>/dev/null && [ -L "$HOME/.opencode" ] || return 1
            ;;
        nvim)
            command -v nvim &>/dev/null && [ -L "$HOME/.config/nvim" ] || return 1
            ;;
        tmux)
            command -v tmux &>/dev/null && [ -L "$HOME/.tmux.conf" ] || return 1
            ;;
        wezterm)
            ensure_brew || return 1
            brew list --cask wezterm &>/dev/null && [ -L "$HOME/.wezterm.lua" ] || return 1
            ;;
        claude)
            command -v claude &>/dev/null && [ -L "$HOME/.claude/settings.json" ] || return 1
            ;;
        check-paths)
            local var
            for var in MOP_CONFIGURATION_PATH MOP_CONSOLE_PATH MOP_MONOREPO_PATH MOP_EPOD_PATH; do
                grep -q "^export $var=" "$HOME/.zshrc" 2>/dev/null || return 1
            done
            ;;
        credentials)
            local svc
            for svc in jenkins.morrison.express morrisonexpress.atlassian.net getdata.morrison.express; do
                security find-generic-password -a "$USER" -s "$svc" -w &>/dev/null || return 1
            done
            ;;
        ssh)
            [ -f "$HOME/.ssh/id_ed25519" ] || return 1
            ;;
        gh)
            gh auth status &>/dev/null || return 1
            ;;
        clone)
            local p expanded
            for p in "$MOP_CONSOLE_PATH" "$MOP_CONFIGURATION_PATH" "$MOP_MONOREPO_PATH" "$MOP_EPOD_PATH"; do
                [ -n "$p" ] || return 1
                expanded="${p/\$HOME/$HOME}"
                [ -d "$expanded/.git" ] || return 1
            done
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

function status_tag() {
    if detect_status "$1"; then
        echo "✓ 已安裝"
    else
        echo "未安裝"
    fi
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

function run_step_by_key() {
    local target="$1" i
    for ((i = 0; i < ${#STEP_KEYS[@]}; i++)); do
        [ "${STEP_KEYS[i]}" = "$target" ] || continue
        if ! is_always_run "$target" && detect_status "$target"; then
            echo "✓ 跳過（已安裝）：${STEP_LABELS[i]}"
        else
            run_step "${STEP_SCRIPTS[i]}"
        fi
        return
    done
}

function run_minimal() {
    echo ""
    echo "=== 精簡安裝 ==="
    echo "只安裝核心項目（必要套件、shell 基礎、專案路徑/憑證/SSH/GitHub/clone）。已安裝的會跳過。"
    local key
    for key in "${MINIMAL_KEYS[@]}"; do
        run_step_by_key "$key"
    done
}

function run_full_guided() {
    echo ""
    echo "=== 完整引導安裝 ==="
    echo "已安裝的項目會自動跳過。"
    local i
    for ((i = 0; i < ${#STEP_KEYS[@]}; i++)); do
        if ! is_always_run "${STEP_KEYS[i]}" && detect_status "${STEP_KEYS[i]}"; then
            echo "✓ 跳過（已安裝）：${STEP_LABELS[i]}"
        else
            run_step "${STEP_SCRIPTS[i]}"
        fi
    done
}

function show_menu_loop() {
    local choice i minimal_idx full_idx exit_idx
    local step_count=${#STEP_KEYS[@]}
    minimal_idx=1
    full_idx=$((step_count + 2))
    exit_idx=$((step_count + 3))

    while true; do
        echo ""
        echo "=== 初始化選單 ==="
        echo "請選擇要執行的項目（會即時偵測安裝狀態）。"
        echo ""
        printf "%2d) %s\n" "$minimal_idx" "精簡安裝（只安裝核心項目）"
        echo ""
        for ((i = 0; i < step_count; i++)); do
            printf "%2d) %-36s %s\n" "$((i + 2))" "${STEP_LABELS[i]}" "$(status_tag "${STEP_KEYS[i]}")"
        done
        echo ""
        printf "%2d) %s\n" "$full_idx" "完整引導安裝（依序執行未完成項目）"
        printf "%2d) %s\n" "$exit_idx" "離開"
        echo ""
        read -r -p "請輸入選項：" choice </dev/tty || break

        if [[ -z "$choice" || "$choice" == *[!0-9]* ]]; then
            echo "⚠️  無效的選項：$choice"
            continue
        fi

        if (( choice == exit_idx )); then
            break
        elif (( choice == minimal_idx )); then
            run_minimal
        elif (( choice == full_idx )); then
            run_full_guided
        elif (( choice >= 2 && choice <= step_count + 1 )); then
            run_step "${STEP_SCRIPTS[choice-2]}"
        else
            echo "⚠️  無效的選項：$choice"
        fi
    done
}

print_preflight_summary
load_env_vars
show_menu_loop

echo ""
echo "=== 初始化完成 ==="
echo "請重新啟動 shell，或執行 'source ~/.zshrc' 套用所有變更。"
