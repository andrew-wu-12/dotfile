#!/bin/bash
# Forgejo issue picker for open issues on the homelab repo ($FORGEJO_HOMELAB_REPO); uses worktree-generic.sh
# (plain branch name, no ticket system).
#   enter   create/open the issue's worktree in a new tmux window (branch feature/<number>-<slug>, via `wt -n`)
#   ctrl-o  open the issue in the browser (stays in picker)
#   ctrl-r  force-reload the issue list (busts cache)
#   esc     cancel
# Issue list is cached 5 minutes at /tmp/tmux-forgejo-picker.cache. --fetch prints fzf-ready lines (ctrl-r reload).

set -u

CACHE_FILE="/tmp/tmux-forgejo-picker.cache"
CACHE_TTL=300       # 5 minutes

BOLD=$'\033[1m'
DIM=$'\033[38;2;127;132;156m'
GREEN=$'\033[38;2;166;227;161m'
RESET=$'\033[0m'

TAB=$(printf '\t')
WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/project/worktrees}"
FORGEJO_REPO_NAME="homelab"
FORGEJO_BASE="https://git.tailcb6113.ts.net"
# <owner>/homelab, from the untracked ~/.zshrc.local. Read from the file too,
# since a tmux server started before it existed won't have it in its env.
FORGEJO_OWNER_REPO="${FORGEJO_HOMELAB_REPO:-$(zsh -c 'source ~/.zshrc.local 2>/dev/null; print -r -- "$FORGEJO_HOMELAB_REPO"')}"
if [ -z "$FORGEJO_OWNER_REPO" ]; then
    echo "Set FORGEJO_HOMELAB_REPO=<owner>/homelab in ~/.zshrc.local"; read -r -n 1; exit 1
fi

mocha="--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,\
header:#f5e0dc,info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,fg+:#cdd6f4,\
prompt:#cba6f7,hl+:#f38ba8,border:#585b70"

get_forgejo_token() {
    security find-generic-password -a "$USER" -s "git.tailcb6113.ts.net" -w 2>/dev/null
}

# Deterministic branch-safe slug from an issue title (lowercase, non-alnum runs -> "-", trimmed, 40 chars).
# Must match between the worktree-exists check and the branch `enter` creates: nothing else links an issue to its branch.
slugify() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-40
}

fetch_raw() {
    local token
    token=$(get_forgejo_token)
    if [ -z "$token" ]; then
        printf 'Forgejo token not found\n' >&2
        return 1
    fi
    curl -s -H "Authorization: token $token" \
        "$FORGEJO_BASE/api/v1/repos/$FORGEJO_OWNER_REPO/issues?state=open&type=issues&limit=50" \
    | jq -r '.[] | select(.pull_request == null) | [(.number|tostring), .title] | @tsv'
}

# Outputs tab-delimited lines: NUMBER TAB DISPLAY_LINE
# {1} in fzf references NUMBER; --with-nth=2 shows only DISPLAY_LINE.
build_lines() {
    local force="${1:-}"
    local raw now mod age

    if [ -z "$force" ] && [ -f "$CACHE_FILE" ]; then
        now=$(date +%s)
        mod=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
        age=$(( now - mod ))
        if [ "$age" -lt "$CACHE_TTL" ]; then
            raw=$(cat "$CACHE_FILE")
        fi
    fi

    if [ -z "${raw:-}" ]; then
        raw=$(fetch_raw 2>/dev/null)
        if [ -z "$raw" ]; then
            printf 'ERROR\t  %s  Failed to fetch issues from Forgejo — ctrl-r to retry\n' "${DIM}⚠${RESET}"
            return
        fi
        printf '%s\n' "$raw" > "$CACHE_FILE"
    fi

    printf '%s\n' "$raw" | while IFS="$TAB" read -r number title; do
        [ -z "$number" ] && continue
        local slug wt_dir indicator
        slug=$(slugify "$title")
        wt_dir="$WORKTREE_ROOT/$FORGEJO_REPO_NAME/feature-${number}-${slug}"
        if [ -d "$wt_dir" ]; then
            indicator="${GREEN}✓${RESET}"
        else
            indicator="${DIM}·${RESET}"
        fi
        printf '%s\t%s  %s  %s\n' \
            "$number" \
            "$indicator" \
            "${BOLD}#${number}${RESET}" \
            "$title"
    done
}

if [ "${1:-}" = "--fetch" ]; then
    build_lines "force"
    exit 0
fi

LINES=$(build_lines "")

if [ -z "$LINES" ]; then
    printf 'No open issues found.\n'
    sleep 2
    exit 0
fi

SELF="$HOME/bin/tmux-forgejo-picker.sh"
HEADER='enter:open worktree  ctrl-o:browser  ctrl-r:reload  esc:cancel'

result=$(printf '%s\n' "$LINES" | fzf \
    --ansi \
    --delimiter="$TAB" \
    --with-nth=2 \
    --layout=reverse \
    --border=rounded \
    --header="$HEADER" \
    --header-first \
    --prompt='issue ❯ ' \
    --pointer='▶' \
    --bind="ctrl-o:execute-silent(open '$FORGEJO_BASE/$FORGEJO_OWNER_REPO/issues/{1}')" \
    --bind="ctrl-r:reload($SELF --fetch)" \
    $mocha) || exit 0

[ -z "$result" ] && exit 0

number=$(printf '%s' "$result" | cut -d"$TAB" -f1)
[ -z "$number" ] && exit 0

case "$number" in
    ERROR) exit 0 ;;
esac

# Re-derive the same slug from the cached raw title (not the ANSI-formatted
# display line) to build the exact branch name the indicator check above used.
title=$(awk -F"$TAB" -v n="$number" '$1==n{print $2; exit}' "$CACHE_FILE" 2>/dev/null)
slug=$(slugify "$title")

zsh ~/bin/worktree-generic.sh -n "feature/${number}-${slug}"
