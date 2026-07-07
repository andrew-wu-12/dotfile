#!/usr/bin/env bash
# Publish one deploy plan page to Confluence under a given parent.
# Refuses to overwrite: if a page with the same title already exists in the
# space, it prints the existing page and stops (warn-and-stop) so a curated
# deploy plan is never silently clobbered.
#
# Usage: publish_page.sh <TITLE> <BODY_FILE> <PARENT_ID> [SPACE_KEY]
#   PARENT_ID  required — the deploy-YYYYMMDD folder id (see find_deploy_parent.sh)
#   SPACE_KEY  default MOP
#
# Set DRY_RUN=1 to print the payload + body and skip the POST entirely.
# Requires: JIRA_TOKEN, VPN.
#
# Exit codes: 0 created (or dry-run) | 2 duplicate exists | 1 error.
set -euo pipefail

TITLE="${1:?usage: publish_page.sh <TITLE> <BODY_FILE> <PARENT_ID> [SPACE]}"
BODY_FILE="${2:?body file required}"
PARENT_ID="${3:?parent id required (deploy-YYYYMMDD folder id)}"
SPACE="${4:-MOP}"
: "${JIRA_TOKEN:?JIRA_TOKEN is not set (source ~/.zshrc)}"

WIKI="https://morrisonexpress.atlassian.net/wiki"
[ -f "$BODY_FILE" ] || { echo "{\"error\":\"body file not found: $BODY_FILE\"}"; exit 1; }

ENC_TITLE=$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$TITLE")
EXIST=$(curl -s -u "$JIRA_TOKEN" "$WIKI/rest/api/content?spaceKey=$SPACE&title=$ENC_TITLE&expand=version")
COUNT=$(echo "$EXIST" | jq '.results | length' 2>/dev/null || echo 0)
if [ "${COUNT:-0}" -gt 0 ]; then
  ID=$(echo "$EXIST" | jq -r '.results[0].id')
  UI=$(echo "$EXIST" | jq -r '.results[0]._links.webui // ""')
  echo "{\"status\":\"exists\",\"id\":\"$ID\",\"url\":\"$WIKI$UI\",\"title\":\"$TITLE\"}"
  exit 2
fi

PAYLOAD=$(jq -n \
  --arg title "$TITLE" --arg space "$SPACE" --arg parent "$PARENT_ID" \
  --rawfile body "$BODY_FILE" \
  '{type:"page", title:$title, space:{key:$space},
    ancestors:[{id:$parent}],
    body:{storage:{value:$body, representation:"storage"}}}')

if [ "${DRY_RUN:-}" = "1" ]; then
  echo "$PAYLOAD" | jq '{dry_run:true, title:.title, space:.space.key, parent:.ancestors[0].id}'
  echo "---BODY (storage format)---"
  cat "$BODY_FILE"
  exit 0
fi

RESP=$(curl -s -u "$JIRA_TOKEN" -X POST -H 'Content-Type: application/json' \
  "$WIKI/rest/api/content" -d "$PAYLOAD")
ID=$(echo "$RESP" | jq -r '.id // empty')
if [ -z "$ID" ]; then
  echo "$RESP"
  exit 1
fi
BASE=$(echo "$RESP" | jq -r '._links.base // empty')
UI=$(echo "$RESP" | jq -r '._links.webui // empty')
echo "{\"status\":\"created\",\"id\":\"$ID\",\"url\":\"$BASE$UI\",\"title\":\"$TITLE\"}"
