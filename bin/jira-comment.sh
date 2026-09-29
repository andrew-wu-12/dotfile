#!/usr/bin/env bash
# Post a comment to a Jira ticket (the only write path to Jira in this setup); prints the comment's browse URL.
# Uses REST API v2 (plain Jira-wiki-markup body; v3 would need ADF JSON). The body is read from a FILE, never
# argv: the payload is a multi-line CJK document and argv quoting is where that goes wrong.
# Usage: jira-comment.sh <TICKET-ID> <body-file>
# Requires: JIRA_TOKEN (env, else read from the credential store), jq, curl.
set -euo pipefail

TICKET="${1:?usage: jira-comment.sh <TICKET-ID> <body-file>}"
BODY_FILE="${2:?usage: jira-comment.sh <TICKET-ID> <body-file>}"
: "${JIRA_TOKEN:=$(~/bin/cred-read.sh morrisonexpress.atlassian.net)}"
: "${JIRA_TOKEN:?JIRA_TOKEN not found in the credential store (run init-credentials.sh)}"

command -v jq   >/dev/null || { echo "jq is required"   >&2; exit 1; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }

[ -f "$BODY_FILE" ] || { echo "error: body file not found: $BODY_FILE" >&2; exit 1; }
[ -s "$BODY_FILE" ] || { echo "error: body file is empty: $BODY_FILE" >&2; exit 1; }

BASE="https://morrisonexpress.atlassian.net"
PAYLOAD=$(mktemp)
RESP=$(mktemp)
trap 'rm -f "$PAYLOAD" "$RESP"' EXIT

jq -Rs '{body: .}' "$BODY_FILE" > "$PAYLOAD"

CODE=$(curl -s -o "$RESP" -w '%{http_code}' \
  -u "$JIRA_TOKEN" \
  -X POST \
  -H "Content-Type: application/json" \
  --data @"$PAYLOAD" \
  "$BASE/rest/api/2/issue/$TICKET/comment")

if [ "$CODE" != "201" ]; then
  echo "error: Jira returned HTTP $CODE for $TICKET" >&2
  jq -r '.errorMessages[]? // .errors? // .' "$RESP" >&2 2>/dev/null || cat "$RESP" >&2
  exit 1
fi

ID=$(jq -r '.id // empty' "$RESP")
[ -n "$ID" ] || { echo "error: posted but no comment id in response" >&2; exit 1; }

echo "$BASE/browse/$TICKET?focusedCommentId=$ID"
