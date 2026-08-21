#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/init-lib.sh"

# Ordered step table as three parallel indexed arrays (kept index-aligned so this
# runs under macOS's stock Bash 3.2 — nothing here needs a newer Bash).
STEP_KEYS=(brew required omz base recommend-cli starship opencode nvim tmux wezterm vscode claude check-paths workspace credentials ssh gh clone)
STEP_LABELS=(
    "Homebrew"
    "必要套件（jq、gh、curl、git、stow、nvm）"
    "Oh My Zsh"
    "基礎設定（stow zsh + bin）"
    "推薦 CLI 工具（zoxide、rg、eza、lazygit、terminal-notifier、fzf）"
    "Starship 提示主題"
    "opencode"
    "Nvim 編輯器"
    "Tmux"
    "WezTerm"
    "VS Code"
    "Claude Code"
    "專案路徑設定"
    "Workspace 設定（.workspace.conf）"
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
    "init-vscode.sh"
    "init-claude.sh"
    "init-check-paths.sh"
    "init-workspace.sh"
    "init-credentials.sh"
    "init-ssh.sh"
    "init-gh.sh"
    "init-clone.sh"
)

# Foundation steps auto-prepended silently to every bundle.
FOUNDATION_KEYS=(brew required omz base)

# Bundle labels (1-indexed, parallel to bundle runner functions).
BUNDLE_LABELS=(
    "最小環境設定（VS Code）"
    "個人環境設定（推薦工具 + 終端機）"
    "最小專案初始化（路徑、金鑰、憑證、複製儲存庫）"
    "個人工作區初始化（工作區設定、SSH、GitHub 驗證）"
)

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

# run_script <script_name> [args...]: runs a script from SCRIPT_DIR with optional
# args, handling chmod and exit-code reporting.
function run_script() {
    local script_name="$1"
    shift
    local script_path="$SCRIPT_DIR/$script_name"

    echo ""
    echo "正在執行 $script_name..."

    if [ ! -x "$script_path" ]; then
        echo "→ $script_name 尚未設定為可執行，正在執行 chmod +x..."
        chmod +x "$script_path"
    fi

    "$script_path" "$@"
    local result=$?

    if [ $result -ne 0 ]; then
        echo "⚠️  警告：${script_name} 執行失敗，結束代碼為 ${result}。"
    else
        echo "✓ $script_name 執行成功。"
    fi

    return $result
}

function run_step() {
    run_script "$1"
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

    local _token
    _token=$(cred_find "jenkins.morrison.express") && export JENKINS_TOKEN="$_token"
    _token=$(cred_find "morrisonexpress.atlassian.net") && export JIRA_TOKEN="$_token"
    _token=$(cred_find "getdata.morrison.express") && export GETDATATOKEN="$_token"
}

# Returns 0 when the component for <key> is fully installed/configured.
function detect_status() {
    local key="$1"
    case "$key" in
        brew)
            ensure_pkg_manager || return 1
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
            local cmd plugin required_cmds=(zoxide rg eza lazygit fzf)
            [ "$(detect_pkg_manager)" = "brew" ] && required_cmds+=(terminal-notifier)
            for cmd in "${required_cmds[@]}"; do
                command -v "$cmd" &>/dev/null || return 1
            done
            for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
                [ -f "$(zsh_plugin_file "$plugin")" ] || return 1
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
            ensure_pkg_manager || return 1
            case "$(detect_pkg_manager)" in
                brew) brew list --cask wezterm &>/dev/null || return 1 ;;
                pacman) pacman -Qi wezterm &>/dev/null || return 1 ;;
            esac
            [ -L "$HOME/.wezterm.lua" ] || return 1
            ;;
        vscode)
            command -v code &>/dev/null || return 1
            case "$(detect_pkg_manager)" in
                brew)
                    [ -L "$HOME/Library/Application Support/Code/User/settings.json" ] || return 1
                    ;;
                pacman)
                    [ -L "$HOME/.config/Code/User/settings.json" ] || return 1
                    ;;
            esac
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
        workspace)
            [ -f "$HOME/project/.workspace.conf" ] || return 1
            ;;
        credentials)
            local svc
            for svc in jenkins.morrison.express morrisonexpress.atlassian.net getdata.morrison.express; do
                cred_find "$svc" &>/dev/null || return 1
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

# Returns 0 when all meaningful steps in the given bundle are installed.
function bundle_installed() {
    local key
    case "$1" in
        1)
            detect_status vscode || return 1
            ;;
        2)
            for key in recommend-cli tmux nvim starship wezterm; do
                detect_status "$key" || return 1
            done
            ;;
        3)
            for key in check-paths ssh credentials gh clone; do
                detect_status "$key" || return 1
            done
            ;;
        4)
            gh auth status &>/dev/null || return 1
            ;;
    esac
    return 0
}

function bundle_tag() {
    if bundle_installed "$1"; then
        echo "✓ 已完成"
    else
        echo "未完成"
    fi
}

function print_preflight_summary() {
    echo ""
    echo "=== 初始化總覽 ==="
    echo ""
    echo "提供 4 個安裝組合，每組皆會自動確認基礎環境（Homebrew、必要套件、Oh My Zsh、shell 設定）："
    echo "  1. 最小環境設定：VS Code"
    echo "  2. 個人環境設定：推薦 CLI 工具 + 終端機工具鏈（Tmux、Nvim、Starship、WezTerm）"
    echo "  3. 最小專案初始化：專案路徑、SSH 金鑰、憑證、GitHub CLI、複製 repo"
    echo "  4. 個人工作區初始化：Workspace 設定、工作區 SSH 身分、GitHub CLI 驗證"
    echo ""
    echo "Claude Code / opencode 請選擇「進階 / 個別步驟」安裝。"
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

function run_bundle_foundation() {
    echo ""
    echo "--- 確認基礎環境 ---"
    local key
    for key in "${FOUNDATION_KEYS[@]}"; do
        run_step_by_key "$key"
    done
}

function run_bundle_1() {
    echo ""
    echo "=== 最小環境設定（VS Code）==="
    run_bundle_foundation
    run_step_by_key vscode
}

function run_bundle_2() {
    echo ""
    echo "=== 個人環境設定（推薦工具 + 終端機）==="
    run_bundle_foundation
    local key
    for key in recommend-cli tmux nvim starship wezterm; do
        run_step_by_key "$key"
    done
}

function run_bundle_3() {
    echo ""
    echo "=== 最小專案初始化 ==="
    run_bundle_foundation
    local key
    for key in check-paths ssh credentials gh clone; do
        run_step_by_key "$key"
    done
}

function run_bundle_4() {
    echo ""
    echo "=== 個人工作區初始化 ==="
    run_bundle_foundation

    # workspace: prompt with ~/personal as default; no ~/personal auto-write
    run_script "init-workspace.sh" --default-path ~/personal

    # ssh: workspace-scoped identity only (not full global key setup)
    run_script "init-ssh.sh" --workspace

    # gh: skip if already authenticated
    if gh auth status &>/dev/null; then
        echo "✓ 跳過（已驗證）：GitHub CLI 驗證"
    else
        run_step "init-gh.sh"
    fi
}

function show_advanced_steps() {
    local choice i step_count=${#STEP_KEYS[@]}
    local back_idx=$((step_count + 1))

    while true; do
        echo ""
        echo "=== 進階：個別步驟 ==="
        echo "選擇步驟後會直接執行（忽略已安裝狀態）。"
        echo ""
        for ((i = 0; i < step_count; i++)); do
            printf "%2d) %-40s %s\n" "$((i + 1))" "${STEP_LABELS[i]}" "$(status_tag "${STEP_KEYS[i]}")"
        done
        echo ""
        printf "%2d) %s\n" "$back_idx" "返回上一層"
        echo ""
        read -r -p "請輸入選項：" choice </dev/tty || break

        if [[ -z "$choice" || "$choice" == *[!0-9]* ]]; then
            echo "⚠️  無效的選項：$choice"
            continue
        fi

        if (( choice == back_idx )); then
            break
        elif (( choice >= 1 && choice <= step_count )); then
            run_step "${STEP_SCRIPTS[choice-1]}"
        else
            echo "⚠️  無效的選項：$choice"
        fi
    done
}

function show_menu_loop() {
    local choice i bundle_count=${#BUNDLE_LABELS[@]}
    local advanced_idx=$((bundle_count + 1))
    local exit_idx=$((bundle_count + 2))

    while true; do
        echo ""
        echo "=== 初始化選單 ==="
        echo "請選擇安裝組合："
        echo ""
        for ((i = 0; i < bundle_count; i++)); do
            printf "%2d) %-52s %s\n" "$((i + 1))" "${BUNDLE_LABELS[i]}" "$(bundle_tag "$((i + 1))")"
        done
        echo ""
        printf "%2d) %s\n" "$advanced_idx" "進階 / 個別步驟"
        printf "%2d) %s\n" "$exit_idx" "離開"
        echo ""
        read -r -p "請輸入選項：" choice </dev/tty || break

        if [[ -z "$choice" || "$choice" == *[!0-9]* ]]; then
            echo "⚠️  無效的選項：$choice"
            continue
        fi

        case "$choice" in
            1) run_bundle_1 ;;
            2) run_bundle_2 ;;
            3) run_bundle_3 ;;
            4) run_bundle_4 ;;
            "$advanced_idx") show_advanced_steps ;;
            "$exit_idx") break ;;
            *) echo "⚠️  無效的選項：$choice" ;;
        esac
    done
}

print_preflight_summary
load_env_vars
show_menu_loop

echo ""
echo "=== 初始化完成 ==="
echo "請重新啟動 shell，或執行 'source ~/.zshrc' 套用所有變更。"
