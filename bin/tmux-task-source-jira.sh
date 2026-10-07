#!/bin/bash
# Task source for tmux-window-picker.sh (TASK_SOURCE_CMD): JIRA tickets assigned to you on the MOP board.
#   list         key<TAB>title<TAB>status, skipping tickets that already have a worktree
#   url <key>    browser link for the ticket
#   start <key>  create the ticket's worktree + window via worktree-ticket.sh -n
# Stateless apart from the board id (cached 24h); the picker caches `list` output.

set -u

BOARD_CACHE="/tmp/tmux-jira-picker-board.cache"
BOARD_TTL=86400
JIRA_BASE="https://morrisonexpress.atlassian.net"
JIRA_JQL='assignee = currentUser() AND status IN ("Backlog","Develop","In Progress","DESIGN","SA SIGNOFF","Designing","Approved","Auto Testing","Designed","DEV","DEV VERIFIED","To Do","UAT","UAT VERIFIED","Verified") ORDER BY status ASC, Rank ASC'
WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/project/worktrees}"
MOP_REPO="mop-console-monorepo"
TAB=$(printf '\t')

get_jira_token() {
  local tok
  tok=$(security find-generic-password -a "$USER" -s "morrisonexpress.atlassian.net" -w 2>/dev/null)
  if [ -z "$tok" ]; then
    tok=$(zsh -c 'source ~/.zshrc >/dev/null 2>&1; printf "%s" "$JIRA_TOKEN"' 2>/dev/null)
  fi
  printf '%s' "$tok"
}

get_board_id() {
  local now mod age board_id token
  if [ -f "$BOARD_CACHE" ]; then
    now=$(date +%s)
    mod=$(stat -f %m "$BOARD_CACHE" 2>/dev/null || echo 0)
    age=$(( now - mod ))
    if [ "$age" -lt "$BOARD_TTL" ]; then
      cat "$BOARD_CACHE"
      return
    fi
  fi
  token=$(get_jira_token)
  board_id=$(/usr/bin/curl -s -u "$token" -X GET \
    -H "Accept: application/json" \
    "$JIRA_BASE/rest/agile/1.0/board?projectKeyOrId=MOP&maxResults=1" \
  | jq -r '.values[0].id' 2>/dev/null)
  if [ -z "$board_id" ] || [ "$board_id" = "null" ]; then
    return 1
  fi
  printf '%s' "$board_id" > "$BOARD_CACHE"
  printf '%s' "$board_id"
}

task_list() {
  local token board_id
  token=$(get_jira_token)
  [ -z "$token" ] && return 1
  board_id=$(get_board_id)
  [ -z "$board_id" ] && return 1
  /usr/bin/curl -s -u "$token" -X GET \
    -H "Accept: application/json" \
    -G \
    --data-urlencode "jql=$JIRA_JQL" \
    --data-urlencode "fields=summary,status" \
    --data-urlencode "maxResults=100" \
    "$JIRA_BASE/rest/agile/1.0/board/$board_id/issue" \
  | jq -r '.issues[] | [.key, (.fields.summary | gsub("\t"; " ")), .fields.status.name] | @tsv' \
  | while IFS="$TAB" read -r key title status; do
      [ -z "$key" ] && continue
      [ -d "$WORKTREE_ROOT/$MOP_REPO/$key" ] && continue
      printf '%s\t%s\t%s\n' "$key" "$title" "$status"
    done
}

case "${1:-}" in
  list)  task_list ;;
  url)   [ -n "${2:-}" ] && printf '%s/browse/%s\n' "$JIRA_BASE" "$2" ;;
  start) [ -n "${2:-}" ] && exec zsh ~/bin/worktree-ticket.sh -n "$2" ;;
  *)     echo "usage: ${0##*/} list | url <key> | start <key>" >&2; exit 2 ;;
esac
