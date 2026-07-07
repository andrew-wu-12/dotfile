#!/usr/bin/env bash
# Resolve the metadata a change-log page needs from a Jira ticket:
#   - summary / issue type
#   - 預計上線日 (release date): PM Release Date (10379) preferred over
#     Expected Due Date (10329); check the ticket first, then walk up to the
#     epic if both are empty; stop at the initiative MOP-24745 or a null parent.
#   - Task Release Info (10445): a team convention field carrying
#     {module,url,github_info[]}. Emitted as raw text so the agent can prefer it
#     over git-derived values when it's actually filled (not the empty template).
#
# Usage: resolve_ticket.sh <TICKET-ID>
# Requires: JIRA_TOKEN in the environment, VPN connection.
set -euo pipefail

TICKET="${1:?usage: resolve_ticket.sh <TICKET-ID>}"
: "${JIRA_TOKEN:?JIRA_TOKEN is not set (source ~/.zshrc)}"

API="https://morrisonexpress.atlassian.net/rest/api/3/issue"
STOP_PARENT="MOP-24745"
FIELDS="parent,issuetype,summary,customfield_10379,customfield_10329,customfield_10445"

fetch() { curl -s -u "$JIRA_TOKEN" "$API/$1?fields=$FIELDS"; }
date_of() { echo "$1" | jq -r '.fields.customfield_10379 // .fields.customfield_10329 // empty'; }

CUR=$(fetch "$TICKET")
if [ -z "$(echo "$CUR" | jq -r '.fields // empty')" ]; then
  echo "{\"error\":\"could not fetch $TICKET (check ticket id / VPN / token)\"}"
  exit 1
fi

DATE=$(date_of "$CUR")
DATE_SRC="$TICKET"
NODE="$CUR"
while [ -z "$DATE" ]; do
  PK=$(echo "$NODE" | jq -r '.fields.parent.key // "null"')
  { [ "$PK" = "null" ] || [ "$PK" = "$STOP_PARENT" ]; } && break
  NODE=$(fetch "$PK")
  DATE=$(date_of "$NODE")
  DATE_SRC="$PK"
done
[ -z "$DATE" ] && DATE_SRC=""

# Task Release Info is ADF rich text; flatten to its text content.
TRI=$(echo "$CUR" | jq -r '[.fields.customfield_10445.content[]?.content[]?.text?] | join("")' 2>/dev/null || echo "")

echo "$CUR" | jq \
  --arg ticket "$TICKET" \
  --arg date "$DATE" \
  --arg date_src "$DATE_SRC" \
  --arg tri "$TRI" \
  '{
    ticket: $ticket,
    summary: .fields.summary,
    issue_type: .fields.issuetype.name,
    release_date: (if $date == "" then null else $date end),
    release_date_source: (if $date_src == "" then null else $date_src end),
    task_release_info: (if $tri == "" then null else $tri end)
  }'
