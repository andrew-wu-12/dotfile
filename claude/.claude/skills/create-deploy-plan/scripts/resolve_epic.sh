#!/usr/bin/env bash
# Resolve the deploy-plan subject from the current branch (or an explicit ticket):
#   - branch_ticket : MOP-XXXX parsed from the branch name (or the arg you pass)
#   - epic          : walk up the parent chain to the first Epic. If no Epic is
#                     reached before a null parent (or the initiative MOP-24745),
#                     the top-most node reached IS the subject (epic_found=false) —
#                     this is the common case for standalone Production Support /
#                     Task tickets like MOP-27811 that have no epic.
#   - deploy_date   : PM Release Date (10379) preferred over Expected Due Date
#                     (10329); checked on the branch ticket first, then walking up
#                     the same chain. Used to locate the deploy-YYYYMMDD folder.
#
# Usage: resolve_epic.sh [TICKET-ID]
#   With no arg, parses the ticket from `git rev-parse --abbrev-ref HEAD`
#   (feature/MOP-XXXX, hotfix/MOP-XXXX, uat/MOP-XXXX, ...). Run from the repo
#   whose branch names the ticket.
# Requires: JIRA_TOKEN in the environment, VPN connection.
set -euo pipefail

: "${JIRA_TOKEN:?JIRA_TOKEN is not set (source ~/.zshrc)}"

TICKET="${1:-}"
if [ -z "$TICKET" ]; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  TICKET=$(printf '%s' "$BRANCH" | grep -oiE 'MOP-[0-9]+' | head -n1 | tr '[:lower:]' '[:upper:]')
  if [ -z "$TICKET" ]; then
    echo "{\"error\":\"no MOP-XXXX in branch '$BRANCH' — pass a ticket id explicitly\"}"
    exit 1
  fi
fi

API="https://morrisonexpress.atlassian.net/rest/api/3/issue"
STOP_PARENT="MOP-24745"
FIELDS="parent,issuetype,summary,customfield_10379,customfield_10329"

fetch()   { curl -s -u "$JIRA_TOKEN" "$API/$1?fields=$FIELDS"; }
date_of() { echo "$1" | jq -r '.fields.customfield_10379 // .fields.customfield_10329 // empty'; }

CUR=$(fetch "$TICKET")
if [ -z "$(echo "$CUR" | jq -r '.fields // empty')" ]; then
  echo "{\"error\":\"could not fetch $TICKET (check ticket id / VPN / token)\"}"
  exit 1
fi

# Walk up: find the first Epic (subject) and the first resolvable deploy date.
NODE="$CUR"
KEY="$TICKET"
EPIC_KEY=""; EPIC_SUMMARY=""; EPIC_FOUND=false
DATE=$(date_of "$CUR"); DATE_SRC="$TICKET"
while :; do
  TYPE=$(echo "$NODE" | jq -r '.fields.issuetype.name // ""')
  SUMMARY=$(echo "$NODE" | jq -r '.fields.summary // ""')
  if [ "$TYPE" = "Epic" ]; then
    EPIC_KEY="$KEY"; EPIC_SUMMARY="$SUMMARY"; EPIC_FOUND=true
    [ -z "$DATE" ] && DATE=$(date_of "$NODE") && DATE_SRC="$KEY"
    break
  fi
  # remember the top-most node reached, in case we never hit an Epic
  EPIC_KEY="$KEY"; EPIC_SUMMARY="$SUMMARY"
  PK=$(echo "$NODE" | jq -r '.fields.parent.key // "null"')
  if [ "$PK" = "null" ] || [ "$PK" = "$STOP_PARENT" ]; then
    break
  fi
  NODE=$(fetch "$PK"); KEY="$PK"
  [ -z "$DATE" ] && DATE=$(date_of "$NODE") && DATE_SRC="$KEY"
done
[ -z "$DATE" ] && DATE_SRC=""

jq -n \
  --arg branch_ticket "$TICKET" \
  --arg epic_key "$EPIC_KEY" \
  --arg epic_summary "$EPIC_SUMMARY" \
  --argjson epic_found "$EPIC_FOUND" \
  --arg date "$DATE" \
  --arg date_src "$DATE_SRC" \
  '{
    branch_ticket: $branch_ticket,
    epic_key: $epic_key,
    epic_summary: $epic_summary,
    epic_found: $epic_found,
    deploy_date: (if $date == "" then null else $date end),
    deploy_date_source: (if $date_src == "" then null else $date_src end)
  }'
