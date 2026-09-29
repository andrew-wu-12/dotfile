#!/bin/bash

# Buckets repo-wide hits of an identifier into out-of-scope (auto-dismissed,
# no file opened) vs in-scope (needs judgment, with grep context attached),
# so a caller only has to reason about the small in-scope set instead of every
# raw hit. Directory-prefix bucketing is only safe for an app-local diff — a
# libs/ change is meant to be consumed from any app, so that case instead
# traces which files actually import the changed lib's resolved alias (or
# live under the same lib root).
#
# Usage: identifier-scope-check.sh <identifier> <repo-root> [base-ref] [head-ref]

set -uo pipefail

IDENTIFIER="$1"
REPO="$2"
BASE_REF="${3:-origin/main}"
HEAD_REF="${4:-HEAD}"

cd "$REPO" || exit 1

CHANGED_FILES="$(git diff "$BASE_REF...$HEAD_REF" --name-only)"
LIBS_TOUCHED="$(printf '%s\n' "$CHANGED_FILES" | grep '^libs/' | head -1)"

MODE="app"
ALIAS=""
LIB_ROOT=""
if [ -n "$LIBS_TOUCHED" ]; then
  MODE="libs"
  ALIAS_AND_ROOT="$(python3 - "$LIBS_TOUCHED" <<'PYEOF'
import json, re, sys
target_file = sys.argv[1]
with open("tsconfig.base.json") as f:
    txt = f.read()
txt = re.sub(r'^\s*//.*$', '', txt, flags=re.M)
data = json.loads(txt)
paths = data['compilerOptions']['paths']
best_alias = None
best_root = None
for alias, targets in paths.items():
    for t in targets:
        root = t.split('/src/')[0]
        if target_file.startswith(root + '/'):
            best_alias = alias
            best_root = root
if best_alias:
    print(best_alias + '|' + best_root)
PYEOF
)"
  ALIAS="${ALIAS_AND_ROOT%%|*}"
  LIB_ROOT="${ALIAS_AND_ROOT#*|}"
  if [ -z "$ALIAS" ] || [ "$ALIAS_AND_ROOT" = "$LIB_ROOT" ]; then
    MODE="app"
    ALIAS=""
    LIB_ROOT=""
  fi
fi

SCOPE_PREFIX=""
E2E_PREFIX=""
if [ "$MODE" = "app" ]; then
  SCOPE_PREFIX="$(printf '%s\n' "$CHANGED_FILES" | grep '^apps/' | head -1 | cut -d/ -f1-2)"
  APP_NAME="$(printf '%s' "$SCOPE_PREFIX" | cut -d/ -f2)"
  E2E_PREFIX="apps/${APP_NAME}-e2e"
fi

HITS="$(grep -rnI "$IDENTIFIER" apps libs scripts .github .jenkins \
  --include='*.ts' --include='*.tsx' --include='*.cy.ts' \
  --include='*.json' --include='*.scss' --include='*.sh' --include='*.yml' 2>/dev/null)"

TOTAL=$(printf '%s\n' "$HITS" | grep -c .)

IN_SCOPE_LINES=()
OUT_COUNT=0

while IFS= read -r line; do
  [ -z "$line" ] && continue
  FILE="${line%%:*}"
  if [ "$MODE" = "libs" ]; then
    if grep -qE "from ['\"]${ALIAS}['\"]" "$FILE" 2>/dev/null || [[ "$FILE" == "$LIB_ROOT"/* ]]; then
      IN_SCOPE_LINES+=("$line")
    else
      OUT_COUNT=$((OUT_COUNT+1))
    fi
  else
    if [[ "$FILE" == "$SCOPE_PREFIX"/* || ( -n "$E2E_PREFIX" && "$FILE" == "$E2E_PREFIX"/* ) ]]; then
      IN_SCOPE_LINES+=("$line")
    else
      OUT_COUNT=$((OUT_COUNT+1))
    fi
  fi
done <<< "$HITS"

echo "=== Scope-filtered identifier check: $IDENTIFIER ==="
echo "Mode: $MODE"
[ "$MODE" = "libs" ] && echo "Lib alias: $ALIAS (root: $LIB_ROOT)"
[ "$MODE" = "app" ] && echo "App scope: $SCOPE_PREFIX (+ $E2E_PREFIX)"
echo "Total raw hits: $TOTAL"
echo "Out-of-scope (auto-dismissed, no file opened): $OUT_COUNT"
echo "In-scope (needs judgment): ${#IN_SCOPE_LINES[@]}"
echo ""
if [ "${#IN_SCOPE_LINES[@]}" -eq 0 ]; then
  echo "(none in scope)"
else
  for l in "${IN_SCOPE_LINES[@]}"; do
    F="${l%%:*}"
    REST="${l#*:}"
    LN="${REST%%:*}"
    echo "--- $l ---"
    START=$(( LN>3 ? LN-3 : 1 ))
    END=$(( LN+3 ))
    sed -n "${START},${END}p" "$F"
    echo ""
  done
fi
