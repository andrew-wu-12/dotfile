#!/usr/bin/env bash
# Locate the deploy-YYYYMMDD parent folder for a deploy plan.
#
# The dated deploy nodes (deploy-2026 / deploy-202607 / deploy-20260707) are
# Confluence *folder* content-type, not pages, so a plain title lookup
# (?title=, which defaults to type=page) misses them — we must use CQL, which
# returns all content types. A page CAN be parented under a folder, so the
# returned id is usable directly as the ancestor for publish_page.sh.
#
# Usage: find_deploy_parent.sh <YYYYMMDD> [SPACE_KEY]
#   SPACE_KEY default MOP
# Output (stdout, JSON):
#   found     -> {"status":"found","id":..,"title":..,"url":..}
#   not found -> {"status":"not_found","title":"deploy-YYYYMMDD"}  (exit 2)
# Exit: 0 found | 2 not found | 1 error
# Requires: JIRA_TOKEN, VPN.
set -euo pipefail

DATE="${1:?usage: find_deploy_parent.sh <YYYYMMDD> [SPACE]}"
SPACE="${2:-MOP}"
: "${JIRA_TOKEN:?JIRA_TOKEN is not set (source ~/.zshrc)}"

WIKI="https://morrisonexpress.atlassian.net/wiki"
TITLE="deploy-$DATE"

CQL=$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(f"space={sys.argv[1]} and title=\"{sys.argv[2]}\"") )' "$SPACE" "$TITLE")
RESP=$(curl -s -u "$JIRA_TOKEN" "$WIKI/rest/api/content/search?cql=$CQL&limit=5")

COUNT=$(echo "$RESP" | jq '.results | length' 2>/dev/null || echo 0)
if [ "${COUNT:-0}" -eq 0 ]; then
  echo "{\"status\":\"not_found\",\"title\":\"$TITLE\"}"
  exit 2
fi

ID=$(echo "$RESP" | jq -r '.results[0].id')
UI=$(echo "$RESP" | jq -r '.results[0]._links.webui // ""')
echo "{\"status\":\"found\",\"id\":\"$ID\",\"title\":\"$TITLE\",\"url\":\"$WIKI$UI\"}"
