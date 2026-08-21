#!/bin/bash
# JIRA ticket picker for active MOP tickets assigned to the current user.
#
#   enter    Open (or create) the ticket worktree in a new tmux window via mwt -n
#   ctrl-o   Open the ticket in the browser (stays in picker)
#   ctrl-r   Force-reload the ticket list from JIRA (busts cache)
#   esc      Cancel
#
# Ticket list is cached for 5 minutes at /tmp/tmux-jira-picker.cache.
# Board ID (resolved from project key MOP) is cached for 24 hours.
#
# --fetch: print fzf-ready lines to stdout (used by ctrl-r reload binding).

set -u

CACHE_FILE="/tmp/tmux-jira-picker.cache"
BOARD_CACHE="/tmp/tmux-jira-picker-board.cache"
CACHE_TTL=300       # 5 minutes
BOARD_TTL=86400     # 24 hours

BOLD=$'\033[1m'
DIM=$'\033[38;2;127;132;156m'
GREEN=$'\033[38;2;166;227;161m'
RESET=$'\033[0m'

TAB=$(printf '\t')
WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/project/worktrees}"
MOP_REPO="mop-console-monorepo"
JIRA_BASE="https://morrisonexpress.atlassian.net"
JIRA_JQL='assignee = currentUser() AND status IN ("Backlog","Develop","In Progress","DESIGN","SA SIGNOFF","Designing","Approved","Auto Testing","Designed","DEV","DEV VERIFIED","To Do","UAT","UAT VERIFIED","Verified") ORDER BY status ASC, Rank ASC'

mocha="--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,\
header:#f5e0dc,info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,fg+:#cdd6f4,\
prompt:#cba6f7,hl+:#f38ba8,border:#585b70"

get_jira_token() {
    local tok
    tok=$(security find-generic-password -a "$USER" -s "morrisonexpress.atlassian.net" -w 2>/dev/null)
    if [ -z "$tok" ]; then
        tok=$(zsh -c 'source ~/.zshrc >/dev/null 2>&1; printf "%s" "$JIRA_TOKEN"' 2>/dev/null)
    fi
    printf '%s' "$tok"
}

# Resolve the numeric board ID for the MOP project; cache for 24h.
get_board_id() {
    local now mod age board_id
    if [ -f "$BOARD_CACHE" ]; then
        now=$(date +%s)
        mod=$(stat -f %m "$BOARD_CACHE" 2>/dev/null || echo 0)
        age=$(( now - mod ))
        if [ "$age" -lt "$BOARD_TTL" ]; then
            cat "$BOARD_CACHE"
            return
        fi
    fi
    local token
    token=$(get_jira_token)
    board_id=$(/usr/bin/curl -s -u "$token" -X GET \
        -H "Accept: application/json" \
        "$JIRA_BASE/rest/agile/1.0/board?projectKeyOrId=MOP&maxResults=1" \
    | jq -r '.values[0].id' 2>/dev/null)
    if [ -z "$board_id" ] || [ "$board_id" = "null" ]; then
        printf 'ERROR: could not resolve MOP board ID\n' >&2
        return 1
    fi
    printf '%s' "$board_id" > "$BOARD_CACHE"
    printf '%s' "$board_id"
}

fetch_raw() {
    local token board_id
    token=$(get_jira_token)
    if [ -z "$token" ]; then
        printf 'JIRA token not found\n' >&2
        return 1
    fi
    board_id=$(get_board_id)
    if [ -z "$board_id" ]; then
        return 1
    fi
    /usr/bin/curl -s -u "$token" -X GET \
        -H "Accept: application/json" \
        -G \
        --data-urlencode "jql=$JIRA_JQL" \
        --data-urlencode "fields=summary,status" \
        --data-urlencode "maxResults=100" \
        "$JIRA_BASE/rest/agile/1.0/board/$board_id/issue" \
    | jq -r '.issues[] | [.key, .fields.status.name, .fields.summary] | @tsv'
}

# Outputs tab-delimited lines: TICKET TAB DISPLAY_LINE
# {1} in fzf references TICKET; --with-nth=2 shows only DISPLAY_LINE.
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
            printf 'ERROR\t  %s  Failed to fetch tickets from JIRA — ctrl-r to retry\n' "${DIM}⚠${RESET}"
            return
        fi
        printf '%s\n' "$raw" > "$CACHE_FILE"
    fi

    printf '%s\n' "$raw" | while IFS="$TAB" read -r ticket status summary; do
        [ -z "$ticket" ] && continue
        summary=$(printf '%s' "$summary" | tr '\t' ' ')
        local wt_dir indicator status_padded
        wt_dir="$WORKTREE_ROOT/$MOP_REPO/$ticket"
        if [ -d "$wt_dir" ]; then
            indicator="${GREEN}✓${RESET}"
        else
            indicator="${DIM}·${RESET}"
        fi
        status_padded=$(printf '%-14s' "$status")
        printf '%s\t%s  %s  %s  %s\n' \
            "$ticket" \
            "$indicator" \
            "${BOLD}${ticket}${RESET}" \
            "${DIM}[${status_padded}]${RESET}" \
            "$summary"
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
    printf 'No tickets found.\n'
    sleep 2
    exit 0
fi

SELF="$HOME/bin/tmux-jira-picker.sh"
HEADER='enter:open worktree  ctrl-o:browser  ctrl-r:reload  esc:cancel'

result=$(printf '%s\n' "$LINES" | fzf \
    --ansi \
    --delimiter="$TAB" \
    --with-nth=2 \
    --layout=reverse \
    --border=rounded \
    --header="$HEADER" \
    --header-first \
    --prompt='ticket ❯ ' \
    --pointer='▶' \
    --bind="ctrl-o:execute-silent(open '$JIRA_BASE/browse/{1}')" \
    --bind="ctrl-r:reload($SELF --fetch)" \
    $mocha) || exit 0

[ -z "$result" ] && exit 0

ticket=$(printf '%s' "$result" | cut -d"$TAB" -f1)
[ -z "$ticket" ] && exit 0

case "$ticket" in
    ERROR) exit 0 ;;
esac

zsh ~/bin/worktree-ticket.sh -n "$ticket"
