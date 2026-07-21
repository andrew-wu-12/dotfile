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
