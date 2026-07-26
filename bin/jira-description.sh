#!/usr/bin/env bash
# Read or overwrite a Jira ticket's description. The second write path to Jira in
# this setup (jira-comment.sh is the first), and the only DESTRUCTIVE one — a PUT
# replaces the field outright, so callers must run their own ownership guard first.
#
# REST API v2 is used in both directions: its description is a plain Jira-wiki-
# markup string (v3 would require ADF JSON). Jira Cloud stores ADF internally and
# converts on the way in and out, so `get` after `set` is NOT byte-identical to
# what was sent — never compare the two for equality.
#
# `set` reads the body from a FILE, never from argv, for the same reason
# jira-comment.sh does: the payload is a multi-line CJK document.
#
# Usage:
#   jira-description.sh get <TICKET-ID>              # raw wiki markup -> stdout
#   jira-description.sh set <TICKET-ID> <body-file>  # overwrite; prints browse URL
# Requires: JIRA_TOKEN in the environment, VPN connection, jq, curl.
set -euo pipefail

ACTION="${1:?usage: jira-description.sh get|set <TICKET-ID> [body-file]}"
TICKET="${2:?usage: jira-description.sh get|set <TICKET-ID> [body-file]}"
: "${JIRA_TOKEN:?JIRA_TOKEN is not set (source ~/.zshrc)}"

command -v jq   >/dev/null || { echo "jq is required"   >&2; exit 1; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }

BASE="https://morrisonexpress.atlassian.net"

case "$ACTION" in
  get)
    RESP=$(mktemp)
    trap 'rm -f "$RESP"' EXIT
    CODE=$(curl -s -o "$RESP" -w '%{http_code}' \
      -u "$JIRA_TOKEN" \
      -H "Content-Type: application/json" \
      "$BASE/rest/api/2/issue/$TICKET?fields=description")

    if [ "$CODE" != "200" ]; then
      echo "error: Jira returned HTTP $CODE for $TICKET" >&2
      jq -r '.errorMessages[]? // .errors? // .' "$RESP" >&2 2>/dev/null || cat "$RESP" >&2
      exit 1
    fi

    # An empty description is null, not "". Emit nothing at all for it — a bare
    # newline is 1 byte, which would make a caller's `[ -s ]` ownership test read
    # an empty description as somebody else's content.
    DESC=$(jq -r '.fields.description // ""' "$RESP")
    if [ -n "$DESC" ]; then printf '%s\n' "$DESC"; fi
    ;;

  set)
    BODY_FILE="${3:?usage: jira-description.sh set <TICKET-ID> <body-file>}"
    [ -f "$BODY_FILE" ] || { echo "error: body file not found: $BODY_FILE" >&2; exit 1; }
    [ -s "$BODY_FILE" ] || { echo "error: body file is empty: $BODY_FILE" >&2; exit 1; }

    # Jira's description field caps at 32767 characters; a PUT over the limit is
    # rejected wholesale, so fail here with a message that says why.
    CHARS=$(wc -m < "$BODY_FILE" | tr -d ' ')
    if [ "$CHARS" -gt 32767 ]; then
      echo "error: description is $CHARS chars; Jira's limit is 32767" >&2
      exit 1
    fi

    PAYLOAD=$(mktemp)
    RESP=$(mktemp)
    trap 'rm -f "$PAYLOAD" "$RESP"' EXIT

    jq -Rs '{fields: {description: .}}' "$BODY_FILE" > "$PAYLOAD"

    CODE=$(curl -s -o "$RESP" -w '%{http_code}' \
      -u "$JIRA_TOKEN" \
      -X PUT \
      -H "Content-Type: application/json" \
      --data @"$PAYLOAD" \
      "$BASE/rest/api/2/issue/$TICKET")

    # A successful PUT returns 204 with no body.
    if [ "$CODE" != "204" ]; then
      echo "error: Jira returned HTTP $CODE for $TICKET" >&2
      jq -r '.errorMessages[]? // .errors? // .' "$RESP" >&2 2>/dev/null || cat "$RESP" >&2
      exit 1
    fi

    echo "$BASE/browse/$TICKET"
    ;;

  *)
    echo "error: unknown action '$ACTION' (expected get or set)" >&2
    exit 1
    ;;
esac
