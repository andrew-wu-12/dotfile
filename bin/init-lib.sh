#!/bin/bash
# Shared helpers for the init-*.sh scripts. Source this, don't execute it.
#
# Callers must set REPO_ROOT first; use resolve_repo_root below.

# Locate the dotfile repo. The naive "parent of my directory" calculation breaks
# when a script is invoked through its ~/bin symlink (dirname sees ~/bin, so the
# parent comes out as $HOME), so validate the result and fall back.
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

# Put brew on PATH for this process. A freshly-installed brew is not on PATH until
# `brew shellenv` is evaluated, so detecting the binary is not enough on its own.
function ensure_brew() {
    command -v brew &>/dev/null && return 0
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        return 0
    fi
    return 1
}

# Package manager abstraction -------------------------------------------------
#
# macOS uses Homebrew; Arch Linux uses pacman for anything in the official
# repos and an AUR helper (yay) for everything else (e.g. wezterm, opencode).
# Callers install by the same package name on both platforms — that holds for
# everything this repo currently installs, so there is no per-platform name
# table yet; add one if a future package's name actually diverges.

PKG_MANAGER=""

# Detects and caches which package manager this machine uses. Echoes "brew" or
# "pacman"; returns 1 with nothing echoed if neither is present.
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

# Confirms the OS package manager is usable. macOS: delegates to ensure_brew,
# since a freshly-installed brew isn't on PATH until `brew shellenv` runs.
# Arch: pacman ships with the base system, so there is nothing to bootstrap —
# this just confirms it is there. AUR packages need more than this; see
# ensure_aur_helper, called separately since not every install needs one.
function ensure_pkg_manager() {
    case "$(detect_pkg_manager)" in
        brew) ensure_brew ;;
        pacman) command -v pacman &>/dev/null ;;
        *) return 1 ;;
    esac
}

# Bootstraps an AUR helper (yay) on Arch, asking first since it builds from
# source via makepkg rather than fetching a binary. No-op success on macOS,
# where AUR has no meaning.
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

# Installs a package. brew_name is what Homebrew calls it; pacman_name is
# what pacman/AUR calls it, defaulting to brew_name since most packages this
# repo installs share a name across both (e.g. "starship", "ripgrep"). Pass it
# explicitly when they diverge (e.g. `pkg_install nvim neovim`).
#
# modifier tells each package manager how to interpret the request, and is
# meaningless (and ignored) on the other platform:
#   cask - macOS GUI app, installed via `brew install --cask` (on Arch, GUI
#          apps are just regular packages, so this is a no-op there)
#   aur  - not in Arch's official repos, needs an AUR helper (Homebrew has no
#          such split, so this is a no-op on macOS)
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

# Secret storage abstraction ---------------------------------------------
#
# macOS uses Keychain (`security`), builtin to the OS. Arch has no equivalent
# builtin, so it uses secret-tool (libsecret) against a Secret Service
# provider (gnome-keyring or equivalent) — this assumes a desktop login
# (GNOME/KDE) already unlocks that keyring via PAM; a minimal-WM setup with
# no such hook needs its own bootstrap, out of scope here. Items are keyed by
# (service, account) on both backends so callers never need to branch.

# Makes sure a secret backend is available. No-op on macOS (security ships
# with the OS). On Arch, installs libsecret if secret-tool isn't already
# present. Deliberately never called from cred_find/cred_store themselves —
# detect_status polls those on every menu render, and a status check must
# stay read-only rather than triggering a pacman install.
function ensure_secret_backend() {
    [ "$(detect_pkg_manager)" = "pacman" ] || return 0
    command -v secret-tool &>/dev/null && return 0
    pkg_install libsecret
}

# Looks up a stored secret by service name. Echoes the secret, or nothing
# (with a non-zero return) if not found.
function cred_find() {
    local service="$1"
    if command -v security &>/dev/null; then
        security find-generic-password -a "$USER" -s "$service" -w 2>/dev/null
    else
        secret-tool lookup service "$service" account "$USER" 2>/dev/null
    fi
}

# Stores (or overwrites) a secret under a service name.
function cred_store() {
    local service="$1" label="$2" value="$3"
    if command -v security &>/dev/null; then
        security add-generic-password -a "$USER" -s "$service" -w "$value" -U
    else
        printf '%s' "$value" | secret-tool store --label="$label" service "$service" account "$USER"
    fi
}

# Clipboard abstraction ----------------------------------------------------
#
# macOS ships pbcopy/pbpaste, builtin. Arch has no equivalent, and which tool
# works depends on the session type: wl-clipboard (wl-copy/wl-paste) under
# Wayland, xclip under X11 — $WAYLAND_DISPLAY is only set in the former, so
# it picks the right one at call time rather than assuming one session type.

# Installs the clipboard tool needed for the current session. No-op on
# macOS and when the tool is already present.
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

# Copies stdin to the system clipboard.
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

# Prints the system clipboard's contents to stdout.
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

# Date arithmetic ----------------------------------------------------------
#
# macOS ships BSD date (`-v-14d`); Arch ships GNU date (`-d "-14 days"`) —
# incompatible flags for the same relative-date computation.

# Echoes the date N days ago, formatted %Y-%m-%d.
function date_days_ago() {
    local days="$1"
    if [ "$(detect_pkg_manager)" = "brew" ]; then
        date -v-"${days}"d +%Y-%m-%d
    else
        date -d "-${days} days" +%Y-%m-%d
    fi
}

# SSH agent ------------------------------------------------------------------
#
# macOS's ssh-add takes --apple-use-keychain to persist a key's passphrase in
# Keychain; no other platform has that flag. The keys this repo generates are
# all `-N ""` (no passphrase — see generate_ssh_key), so there is nothing for
# the flag to actually persist here; it's dropped on Arch rather than
# replaced, since there's no passphrase-caching problem to solve.

# Adds a key to the running ssh-agent, using Keychain persistence on macOS.
function ssh_add_key() {
    local key_path="$1"
    if [ "$(detect_pkg_manager)" = "brew" ]; then
        ssh-add --apple-use-keychain "$key_path" 2>/dev/null
    else
        ssh-add "$key_path" 2>/dev/null
    fi
}

# Full path to a zsh plugin's main sourced file, given its brew/pacman package
# name (identical for zsh-autosuggestions / zsh-syntax-highlighting on both
# platforms — only the share-dir prefix differs).
function zsh_plugin_file() {
    case "$(detect_pkg_manager)" in
        brew) echo "/opt/homebrew/share/$1/$1.zsh" ;;
        pacman) echo "/usr/share/$1/$1.zsh" ;;
        *) return 1 ;;
    esac
}

# Package name -> stow target dir. Everything lands in $HOME except bin.
function stow_target_for() {
    case "$1" in
        bin) echo "$HOME/bin" ;;
        *) echo "$HOME" ;;
    esac
}

# Paths (relative to the target dir) that stow refuses to overwrite because
# something real is already sitting there.
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

# Stow a package, asking before touching anything real that is already in place.
# "Keep" leaves the target alone and skips the whole package — the repo is never
# written to, which is why --adopt is deliberately not used anywhere.
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
