#!/usr/bin/env bash
# Fetch a Jira ticket into a machine-readable manifest for the spec skills.
#
# Emits a JSON manifest to stdout:
#   { ticket, type, summary, priority, status, parent,
#     description,                      # rendered, HTML-stripped plain text
#     comments: [ { author, created, body } ],
#     attachments: [ { filename, mime, path } ] }   # images only, downloaded
#
# Image attachments are downloaded into <out_dir>/attachments/ so the caller can
# Read them (prototype screenshots feed the spec). Non-image attachments are
# listed in the manifest with an empty path but not downloaded.
#
# Usage: fetch-ticket.sh <TICKET-ID> <out_dir>
# Requires: JIRA_TOKEN in the environment, VPN connection, jq, curl.
set -euo pipefail

TICKET="${1:?usage: fetch-ticket.sh <TICKET-ID> <out_dir>}"
OUT_DIR="${2:?usage: fetch-ticket.sh <TICKET-ID> <out_dir>}"
: "${JIRA_TOKEN:?JIRA_TOKEN is not set (source ~/.zshrc)}"

command -v jq   >/dev/null || { echo "jq is required"   >&2; exit 1; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }

API="https://morrisonexpress.atlassian.net/rest/api/3/issue"
STOP_PARENT="MOP-24745"

mkdir -p "$OUT_DIR/attachments"
RAW="$OUT_DIR/.raw.json"

curl -s -u "$JIRA_TOKEN" -H "Content-Type: application/json" \
  "$API/$TICKET?expand=renderedFields" > "$RAW"

if ! jq -e '.fields // empty' "$RAW" >/dev/null 2>&1; then
  echo "error: could not fetch $TICKET (check ticket id / VPN / token)" >&2
  exit 1
fi

# Download image attachments; build a JSON array of what we stored.
ATTACH_MANIFEST="$OUT_DIR/.attachments.json"
echo '[]' > "$ATTACH_MANIFEST"
while IFS=$'\t' read -r url filename mime; do
  [ -z "$url" ] && continue
  case "$mime" in
    image/*) ;;
    *)  ATTACH_MANIFEST_TMP=$(jq --arg f "$filename" --arg m "$mime" \
          '. + [{filename:$f, mime:$m, path:""}]' "$ATTACH_MANIFEST")
        echo "$ATTACH_MANIFEST_TMP" > "$ATTACH_MANIFEST"; continue ;;
  esac
  safe=$(echo "$filename" | sed 's/[^a-zA-Z0-9._-]/_/g')
  dest="$OUT_DIR/attachments/$safe"
  if curl -s -u "$JIRA_TOKEN" -L -o "$dest" "$url" && [ -s "$dest" ]; then
    ATTACH_MANIFEST_TMP=$(jq --arg f "$filename" --arg m "$mime" --arg p "$dest" \
      '. + [{filename:$f, mime:$m, path:$p}]' "$ATTACH_MANIFEST")
    echo "$ATTACH_MANIFEST_TMP" > "$ATTACH_MANIFEST"
  fi
done < <(jq -r '.fields.attachment[]? | [.content, .filename, .mimeType] | @tsv' "$RAW")

# Normalize parent (drop the initiative root).
PARENT=$(jq -r '.fields.parent.key // "null"' "$RAW")
[ "$PARENT" = "$STOP_PARENT" ] && PARENT="null"

jq -n \
  --slurpfile raw "$RAW" \
  --slurpfile attach "$ATTACH_MANIFEST" \
  --arg ticket "$TICKET" \
  --arg parent "$PARENT" '
  # Drop tags, decode entities (named + numeric &#NN;), collapse blank runs.
  def strip:
    gsub("<br[^>]*>";"\n") | gsub("</p>";"\n") | gsub("<li>";"- ")
    | gsub("<[^>]*>";"")
    | gsub("&#(?<d>[0-9]+);"; ([.d|tonumber]|implode))
    | gsub("&nbsp;";" ") | gsub("&amp;";"&")
    | gsub("&lt;";"<") | gsub("&gt;";">") | gsub("&quot;";"\"")
    | gsub("\n[ \t]*\n[ \t]*\n+";"\n\n");
  {
    ticket: $ticket,
    type:     ($raw[0].fields.issuetype.name // null),
    summary:  ($raw[0].fields.summary // null),
    priority: ($raw[0].fields.priority.name // null),
    status:   ($raw[0].fields.status.name // null),
    labels:   ($raw[0].fields.labels // []),
    parent:   (if $parent == "null" then null else $parent end),
    description: (($raw[0].renderedFields.description // "") | strip),
    comments: [ $raw[0].renderedFields.comment.comments[]? as $c
                | { author: ($c.author.displayName // "unknown"),
                    created: ($c.created // ""),
                    body: (($c.body // "") | strip) } ],
    attachments: $attach[0]
  }'

rm -f "$RAW" "$ATTACH_MANIFEST"
