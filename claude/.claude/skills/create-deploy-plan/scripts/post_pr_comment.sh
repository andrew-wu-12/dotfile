#!/usr/bin/env bash
# Post a PR link as a native Confluence comment on a deploy plan page.
# Two lookup modes:
#   - default (frontend):  head=<branch> base=main   in mop-console-monorepo
#   - --search-title mode: ticket-title search on --base in --repo (used for
#     mop_configuration_files, whose branches don't follow the ticket-name
#     convention — so we match by ticket key in the PR title instead)
#
# Usage:
#   post_pr_comment.sh <PAGE_ID> [--branch <BRANCH>] [--url <PR_URL>]
#   post_pr_comment.sh <PAGE_ID> --search-title <TICKET> --repo <owner/repo> --base <BASE> [--label <LABEL>] [--url <PR_URL>]
#
#   PAGE_ID        required — the deploy plan page id (see publish_page.sh output)
#   --branch       frontend mode only; defaults to the current git branch
#   --search-title switches to title-search mode: gh pr list --repo <repo> --base <base>
#                  --state open --search "<TICKET> in:title"
#   --repo         owner/repo for --search-title mode (gh --repo flag)
#   --base         base branch for --search-title mode (e.g. master)
#   --label        comment label line; default "Frontend PR", or "Config PR"
#                  when --search-title is used and --label is omitted
#   --url          skip the gh lookup and post this PR URL directly — use this
#                  when no open PR is found, or a title search is ambiguous
#
# Comment body is fixed: "<label>" on one line, the PR link on the next.
#
# Exit codes: 0 posted | 2 no open PR found | 3 ambiguous (multiple title
# matches — ask the user to disambiguate / supply --url) | 1 error.
# Requires: JIRA_TOKEN, VPN, gh CLI authenticated (for the non---url path).
set -euo pipefail

PAGE_ID="${1:?usage: post_pr_comment.sh <PAGE_ID> [--branch <BRANCH> | --search-title <TICKET> --repo <owner/repo> --base <BASE>] [--label <LABEL>] [--url <PR_URL>]}"
shift
: "${JIRA_TOKEN:?JIRA_TOKEN is not set (source ~/.zshrc)}"

BRANCH=""
PR_URL=""
SEARCH_TITLE=""
REPO=""
BASE="main"
LABEL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    --url) PR_URL="$2"; shift 2 ;;
    --search-title) SEARCH_TITLE="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --base) BASE="$2"; shift 2 ;;
    --label) LABEL="$2"; shift 2 ;;
    *) echo "{\"error\":\"unknown arg: $1\"}"; exit 1 ;;
  esac
done

if [ -z "$PR_URL" ]; then
  if [ -n "$SEARCH_TITLE" ]; then
    [ -z "$REPO" ] && { echo '{"error":"--search-title requires --repo"}'; exit 1; }
    [ -z "$LABEL" ] && LABEL="Config PR"
    MATCHES=$(gh pr list --repo "$REPO" --base "$BASE" --state open \
      --search "$SEARCH_TITLE in:title" --json url,title 2>/dev/null || echo '[]')
    COUNT=$(echo "$MATCHES" | jq 'length')
    if [ "$COUNT" -eq 0 ]; then
      echo "{\"status\":\"no_pr_found\",\"repo\":\"$REPO\",\"base\":\"$BASE\",\"search\":\"$SEARCH_TITLE\",\"message\":\"no open PR titled with $SEARCH_TITLE (repo=$REPO, base=$BASE) — ask the user for the PR URL and retry with --url\"}"
      exit 2
    elif [ "$COUNT" -gt 1 ]; then
      echo "{\"status\":\"ambiguous\",\"repo\":\"$REPO\",\"matches\":$MATCHES,\"message\":\"multiple open PRs matched $SEARCH_TITLE in title — ask the user which one, then retry with --url\"}"
      exit 3
    fi
    PR_URL=$(echo "$MATCHES" | jq -r '.[0].url')
  else
    [ -z "$LABEL" ] && LABEL="Frontend PR"
    [ -z "$BRANCH" ] && BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    if [ -z "$BRANCH" ]; then
      echo '{"error":"could not determine branch — pass --branch or --url"}'
      exit 1
    fi
    PR_URL=$(gh pr list --head "$BRANCH" --base "$BASE" --state open \
      --json url --jq '.[0].url // empty' 2>/dev/null || true)
    if [ -z "$PR_URL" ]; then
      echo "{\"status\":\"no_pr_found\",\"branch\":\"$BRANCH\",\"message\":\"no open PR (head=$BRANCH, base=$BASE) — ask the user for the PR URL and retry with --url\"}"
      exit 2
    fi
  fi
fi
[ -z "$LABEL" ] && LABEL="Frontend PR"

WIKI="https://morrisonexpress.atlassian.net/wiki"
BODY="<p>$LABEL</p><p><a href=\"$PR_URL\">$PR_URL</a></p>"

PAYLOAD=$(jq -n \
  --arg id "$PAGE_ID" --arg body "$BODY" \
  '{type:"comment", container:{id:$id, type:"page"},
    body:{storage:{value:$body, representation:"storage"}}}')

RESP=$(curl -s -u "$JIRA_TOKEN" -X POST -H 'Content-Type: application/json' \
  "$WIKI/rest/api/content" -d "$PAYLOAD")
ID=$(echo "$RESP" | jq -r '.id // empty')
if [ -z "$ID" ]; then
  echo "$RESP"
  exit 1
fi
UI=$(echo "$RESP" | jq -r '._links.webui // empty')
echo "{\"status\":\"posted\",\"id\":\"$ID\",\"pr_url\":\"$PR_URL\",\"url\":\"$WIKI$UI\"}"
