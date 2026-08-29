#!/bin/bash
# Forgejo issue picker for open issues on the homelab repo (andrew_wu/homelab).
# Mirrors tmux-jira-picker.sh's structure and keybindings, but keys off
# Forgejo issues instead of Jira tickets, and worktree-generic.sh (no ticket
# system, plain branch name) instead of worktree-ticket.sh (MOP-only).
#
#   enter    Create/open the issue's worktree in a new tmux window
#            (branch feature/<number>-<slug>, via `wt -n`)
#   ctrl-o   Open the issue in the browser (stays in picker)
#   ctrl-r   Force-reload the issue list from Forgejo (busts cache)
#   esc      Cancel
#
# Issue list is cached for 5 minutes at /tmp/tmux-forgejo-picker.cache.
#
# --fetch: print fzf-ready lines to stdout (used by ctrl-r reload binding).

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
FORGEJO_OWNER_REPO="andrew_wu/homelab"

mocha="--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,\
header:#f5e0dc,info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,fg+:#cdd6f4,\
prompt:#cba6f7,hl+:#f38ba8,border:#585b70"

get_forgejo_token() {
    security find-generic-password -a "$USER" -s "git.tailcb6113.ts.net" -w 2>/dev/null
}

# Deterministic branch-safe slug from an issue title: lowercase, non-alnum
# runs collapsed to a single "-", trimmed, capped at 40 chars. Must match
# exactly between the worktree-exists check and the branch name `enter`
# creates, since there's no other link between an issue and its branch.
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

# --fetch mode: force-fetch, write cache, print lines (called by fzf ctrl-r reload)
if [ "${1:-}" = "--fetch" ]; then
    build_lines "force"
    exit 0
fi

# Main picker
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
