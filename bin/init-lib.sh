#!/bin/bash
# Shared helpers for the init-*.sh scripts (source, don't execute). Callers must set REPO_ROOT first via resolve_repo_root.

# "Parent of my directory" breaks when a script runs through its ~/bin symlink (dirname sees ~/bin, so the
# parent is $HOME), so validate the result and fall back.
function resolve_repo_root() {
    local script_dir="$1" candidate
    candidate="$(dirname "$script_dir")"
    if [ ! -d "$candidate/zsh" ]; then
        candidate="${DOTFILE_ROOT:-$HOME/dotfile}"
    fi
    if [ ! -d "$candidate/zsh" ]; then
        echo "錯誤：找不到 dotfile repo（試過 $(dirname "$script_dir") 與 ${candidate}）" >&2
        echo "提示：可設定 DOTFILE_ROOT 環境變數指向 repo 位置。" >&2
        return 1
    fi
    echo "$candidate"
}

# A freshly-installed brew is not on PATH until `brew shellenv` runs, so detecting the binary isn't enough.
function ensure_brew() {
    command -v brew &>/dev/null && return 0
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        return 0
    fi
    return 1
}

# Package manager abstraction: brew on macOS; pacman (official repos) + yay (AUR) on Arch. Package names are
# shared across platforms; divergences are passed explicitly at the call site.

PKG_MANAGER=""

function detect_pkg_manager() {
    if [ -z "$PKG_MANAGER" ]; then
        if [[ "$(uname -s)" == "Darwin" ]]; then
            PKG_MANAGER="brew"
        elif command -v pacman &>/dev/null; then
            PKG_MANAGER="pacman"
        else
            return 1
        fi
    fi
    echo "$PKG_MANAGER"
}

# macOS delegates to ensure_brew; Arch ships pacman in the base system, so this only confirms it.
# AUR needs ensure_aur_helper, called separately since not every install does.
function ensure_pkg_manager() {
    case "$(detect_pkg_manager)" in
        brew) ensure_brew ;;
        pacman) command -v pacman &>/dev/null ;;
        *) return 1 ;;
    esac
}

# Bootstraps yay on Arch (asks first: it builds from source via makepkg); no-op on macOS.
function ensure_aur_helper() {
    [ "$(detect_pkg_manager)" = "pacman" ] || return 0
    command -v yay &>/dev/null && return 0

    local answer
    echo "尚未安裝 AUR 輔助工具（yay）。安裝這個套件需要它。"
    read -r -p "現在從原始碼建置並安裝 yay 嗎？[y/N]：" answer </dev/tty
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "已略過。之後可手動安裝：https://github.com/Jguer/yay"
        return 1
    fi

    local tmp_dir result
    tmp_dir="$(mktemp -d)" || return 1
    sudo pacman -S --needed --noconfirm base-devel git \
        && git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay" \
        && ( cd "$tmp_dir/yay" && makepkg -si --noconfirm )
    result=$?
    rm -rf "$tmp_dir"
    return $result
}

# pacman_name defaults to brew_name; pass it when they diverge (`pkg_install nvim neovim`).
# modifier is ignored on the other platform: cask = `brew install --cask` (no-op on Arch, where GUI apps are
# regular packages); aur = install via yay (no-op on macOS).
function pkg_install() {
    local brew_name="$1" pacman_name="${2:-$1}" modifier="${3:-}"

    case "$(detect_pkg_manager)" in
        brew)
            if [ "$modifier" = "cask" ]; then
                brew install --cask "$brew_name"
            else
                brew install "$brew_name"
            fi
            ;;
        pacman)
            if [ "$modifier" = "aur" ]; then
                ensure_aur_helper || return 1
                yay -S --needed --noconfirm "$pacman_name"
            else
                sudo pacman -S --needed --noconfirm "$pacman_name"
            fi
            ;;
        *)
            echo "錯誤：找不到支援的套件管理工具（brew 或 pacman）" >&2
            return 1
            ;;
    esac
}

# Secret storage: macOS Keychain (`security`); Arch secret-tool (libsecret) against a Secret Service provider
# (gnome-keyring or equivalent), assuming a desktop login (GNOME/KDE) unlocks the keyring via PAM; a minimal-WM
# setup needs its own bootstrap, out of scope. Items are keyed by (service, account) on both backends.

# No-op on macOS; installs libsecret on Arch. Never called from cred_find/cred_store: detect_status polls
# those on every menu render, and a status check must stay read-only rather than trigger a pacman install.
function ensure_secret_backend() {
    [ "$(detect_pkg_manager)" = "pacman" ] || return 0
    command -v secret-tool &>/dev/null && return 0
    pkg_install libsecret
}

function cred_find() {
    local service="$1"
    if command -v security &>/dev/null; then
        security find-generic-password -a "$USER" -s "$service" -w 2>/dev/null
    else
        secret-tool lookup service "$service" account "$USER" 2>/dev/null
    fi
}

function cred_store() {
    local service="$1" label="$2" value="$3"
    if command -v security &>/dev/null; then
        security add-generic-password -a "$USER" -s "$service" -w "$value" -U
    else
        printf '%s' "$value" | secret-tool store --label="$label" service "$service" account "$USER"
    fi
}

# Clipboard: macOS pbcopy/pbpaste; Arch uses wl-clipboard under Wayland or xclip under X11, chosen at call
# time via $WAYLAND_DISPLAY (only set under Wayland).

function ensure_clipboard_backend() {
    [ "$(detect_pkg_manager)" = "pacman" ] || return 0
    if [ -n "$WAYLAND_DISPLAY" ]; then
        command -v wl-copy &>/dev/null && return 0
        pkg_install wl-clipboard
    else
        command -v xclip &>/dev/null && return 0
        pkg_install xclip
    fi
}

function clip_copy() {
    if command -v pbcopy &>/dev/null; then
        pbcopy
    else
        ensure_clipboard_backend || return 1
        if [ -n "$WAYLAND_DISPLAY" ]; then
            wl-copy
        else
            xclip -selection clipboard
        fi
    fi
}

function clip_paste() {
    if command -v pbpaste &>/dev/null; then
        pbpaste
    else
        ensure_clipboard_backend || return 1
        if [ -n "$WAYLAND_DISPLAY" ]; then
            wl-paste
        else
            xclip -selection clipboard -o
        fi
    fi
}

# BSD date (`-v-14d`, macOS) and GNU date (`-d "-14 days"`, Arch) take incompatible flags.

function date_days_ago() {
    local days="$1"
    if [ "$(detect_pkg_manager)" = "brew" ]; then
        date -v-"${days}"d +%Y-%m-%d
    else
        date -d "-${days} days" +%Y-%m-%d
    fi
}

# --apple-use-keychain is macOS-only. This repo's keys are all `-N ""` (no passphrase), so there is nothing
# to persist; the flag is dropped on Arch rather than replaced.

function ssh_add_key() {
    local key_path="$1"
    if [ "$(detect_pkg_manager)" = "brew" ]; then
        ssh-add --apple-use-keychain "$key_path" 2>/dev/null
    else
        ssh-add "$key_path" 2>/dev/null
    fi
}

# Main sourced file of a zsh plugin; only the share-dir prefix differs by platform.
function zsh_plugin_file() {
    case "$(detect_pkg_manager)" in
        brew) echo "/opt/homebrew/share/$1/$1.zsh" ;;
        pacman) echo "/usr/share/$1/$1.zsh" ;;
        *) return 1 ;;
    esac
}

function stow_target_for() {
    case "$1" in
        bin) echo "$HOME/bin" ;;
        *) echo "$HOME" ;;
    esac
}

function stow_conflicts() {
    local pkg="$1" target="$2"
    ( cd "$REPO_ROOT" && stow -n --restow --target="$target" "$pkg" 2>&1 ) \
        | sed -n 's/.*over existing target \(.*\) since .*/\1/p; s/.*existing target is not owned by stow: //p' \
        | sort -u
}

function backup_stow_conflicts() {
    # Note: not named "path" — that is a special PATH-linked variable in zsh, and
    # these helpers get sourced by scripts that are sometimes run under zsh.
    local target="$1" stamp item
    shift
    stamp="$(date +%Y%m%d%H%M%S)"
    for item in "$@"; do
        [ -e "$target/$item" ] || continue
        mv "$target/$item" "$target/$item.bak.$stamp" || return 1
        echo "  已備份 $item → $item.bak.$stamp"
    done
}

# Stow a package, asking before touching anything real already in place. "Keep" skips the whole package: the
# repo is never written to, which is why --adopt is deliberately not used anywhere.
function stow_pkg() {
    local pkg="$1" target conflicts answer
    target="${2:-$(stow_target_for "$pkg")}"

    if ! command -v stow &>/dev/null; then
        echo "錯誤：找不到 'stow' 指令。請先安裝 GNU Stow。" >&2
        return 1
    fi

    [ -d "$target" ] || mkdir -p "$target" || return 1

    conflicts="$(stow_conflicts "$pkg" "$target")"
    if [ -n "$conflicts" ]; then
        echo ""
        echo "偵測到 $target 已有下列非連結檔案，與 $pkg 套件衝突："
        echo "$conflicts" | sed 's/^/  • /'
        # Braces are required: Bash 3.2 in a UTF-8 locale otherwise absorbs the
        # following multibyte punctuation into the variable name.
        read -r -p "保留現有檔案嗎？（保留 = 跳過 ${pkg}，不做任何變更）[y/N]：" answer </dev/tty
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            echo "⚠️  已保留現有檔案；$pkg 將不受 stow 管理。"
            return 0
        fi
        # shellcheck disable=SC2086
        backup_stow_conflicts "$target" $conflicts || {
            echo "備份失敗，停止 stow $pkg" >&2
            return 1
        }
    fi

    ( cd "$REPO_ROOT" && stow --restow --target="$target" "$pkg" ) || {
        echo "❌ stow $pkg 失敗" >&2
        return 1
    }
    echo "✓ 已連結 $pkg → $target"
}
