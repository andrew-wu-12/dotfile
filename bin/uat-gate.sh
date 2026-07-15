#!/usr/bin/env bash
# Pre-prod gate: verify every ticket whose branch was merged into a uat/* branch
# is in "UAT Verified" before the uat -> main (prod) merge. A guard, not a
# blocker — it reports and exits non-zero if any ticket isn't verified, so you
# make the call.
#
# "Related tickets" = the feature/hotfix branches merged into the uat branch that
# are NOT yet in main (origin/main..origin/<uat-branch>). Anything already
# released (in main) drops out automatically.
#
# Usage:
#   uat-gate.sh                     # current monorepo branch (must be uat/*)
#   uat-gate.sh uat/MOP-24959       # explicit uat branch
#   uat-gate.sh MOP-24959           # shorthand -> uat/MOP-24959
#   UAT_GATE_STATUS="UAT Verified"  # override target status (default shown)
# Requires: JIRA_TOKEN, VPN, run inside $MOP_MONOREPO_PATH (or it cds there).
set -euo pipefail

: "${JIRA_TOKEN:?JIRA_TOKEN is not set (source ~/.zshrc)}"
TARGET_STATUS="${UAT_GATE_STATUS:-UAT VERIFIED}"  # exact MOP workflow status; compare is case-insensitive
MONO="${MOP_MONOREPO_PATH:?set MOP_MONOREPO_PATH}"
API="https://morrisonexpress.atlassian.net/rest/api/3/issue"

cd "$MONO"

ARG="${1:-}"
if [ -z "$ARG" ]; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
elif [[ "$ARG" == uat/* ]]; then
  BRANCH="$ARG"
elif [[ "$ARG" =~ ^MOP-[0-9]+$ ]]; then
  BRANCH="uat/$ARG"
else
  BRANCH="$ARG"
fi

if [[ "$BRANCH" != uat/* ]]; then
  echo "Warning: '$BRANCH' is not a uat/* branch — the gate is meant for a prod (uat -> main) merge." >&2
fi

git fetch -q origin main "$BRANCH" 2>/dev/null || git fetch -q origin || true
RANGE_BASE="origin/main"
RANGE_HEAD="origin/$BRANCH"
git rev-parse --verify -q "$RANGE_HEAD" >/dev/null || RANGE_HEAD="$BRANCH"
git rev-parse --verify -q "$RANGE_BASE" >/dev/null || RANGE_BASE="main"

# Tickets = MOP-id right after feature/ or hotfix/ in merge-commit branch names.
# `|| true`: grep exits 1 on no match, which under `set -o pipefail` would abort
# the whole script inside this assignment before the empty-guard below can report.
TICKETS=$(git log --merges --pretty='%s %b' "$RANGE_BASE..$RANGE_HEAD" 2>/dev/null \
  | grep -oiE '(feature|hotfix)/MOP-[0-9]+' \
  | grep -oiE 'MOP-[0-9]+' | tr 'a-z' 'A-Z' | sort -u || true)

if [ -z "$TICKETS" ]; then
  echo "No merged feature/hotfix tickets found in $RANGE_BASE..$RANGE_HEAD."
  echo "(Nothing to gate, or the branch uses squash-merges without 'Merge pull request' commits.)"
  exit 0
fi

echo "UAT gate for $BRANCH — target status: \"$TARGET_STATUS\""
echo "Tickets in this release (not yet in main):"
echo

NOT_VERIFIED=0
TOTAL=0
while IFS= read -r T; do
  [ -z "$T" ] && continue
  TOTAL=$((TOTAL + 1))
  STATUS=$(curl -s -u "$JIRA_TOKEN" -H "Content-Type: application/json" \
    "$API/$T?fields=status" | jq -r '.fields.status.name // "??"')
  if [ "$(echo "$STATUS" | tr 'A-Z' 'a-z')" = "$(echo "$TARGET_STATUS" | tr 'A-Z' 'a-z')" ]; then
    printf "  \342\234\224 %-12s %s\n" "$T" "$STATUS"
  else
    printf "  \342\234\227 %-12s %s\n" "$T" "$STATUS"
    NOT_VERIFIED=$((NOT_VERIFIED + 1))
  fi
done <<< "$TICKETS"

echo
if [ "$NOT_VERIFIED" -eq 0 ]; then
  echo "All $TOTAL ticket(s) are \"$TARGET_STATUS\". Gate passed."
  exit 0
else
  echo "$NOT_VERIFIED of $TOTAL ticket(s) are NOT \"$TARGET_STATUS\" — review before merging to main."
  exit 3
fi
