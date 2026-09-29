#!/usr/bin/env bash
# Gather everything needed to decide a privilege node's fate, ENV-AWARE.
# The config repo is branch-per-environment (dev / uat / master) and dev gets
# configs first, so a node commonly exists in dev but not yet uat/master. The
# question is rarely "derive a new node" — it is usually "is it in dev, and does
# it need promoting?". Deriving from scratch when dev already has the node is a
# bug (dev may carry children/flags you would not reproduce), so dev is the source
# of truth whenever it has the node.
#
# Reports: per-branch presence (origin/dev|uat|master), the verbatim dev node
# (promotion source) if present, and monorepo usage to derive from ONLY if the
# node is absent everywhere.
#
# Usage: gather_privilege.sh <privilege-id-prefix>   e.g. tms_mgmt.trucker_portal
# Requires: $MOP_CONFIGURATION_PATH, $MOP_MONOREPO_PATH; fetches origin.
set -euo pipefail

PREFIX="${1:?usage: gather_privilege.sh <privilege-id-prefix>}"
CFG="${MOP_CONFIGURATION_PATH:?set MOP_CONFIGURATION_PATH}"
MONO="${MOP_MONOREPO_PATH:?set MOP_MONOREPO_PATH}"

git -C "$CFG" fetch -q origin

node_from_branch() {  # <branch> -> prints matching node json or "NOT FOUND"
  local tmp; tmp=$(mktemp)
  if ! git -C "$CFG" show "origin/$1:privileges.json" > "$tmp" 2>/dev/null; then
    echo "NOT FOUND"; rm -f "$tmp"; return
  fi
  python3 - "$tmp" "$PREFIX" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("NOT FOUND"); sys.exit()
prefix = sys.argv[2]
def find(n, t):
    if n.get('id') == t: return n
    for c in n.get('children', []):
        r = find(c, t)
        if r: return r
n = find(d, prefix)
print(json.dumps(n, indent=2, ensure_ascii=False) if n else "NOT FOUND")
PY
  rm -f "$tmp"
}

echo "### Per-environment presence of '$PREFIX'"
IN_DEV=no; IN_UAT=no; IN_MASTER=no
for b in dev uat master; do
  if [ "$(node_from_branch "$b")" = "NOT FOUND" ]; then
    echo "  origin/$b: ABSENT"
  else
    echo "  origin/$b: present"
    case "$b" in dev) IN_DEV=yes;; uat) IN_UAT=yes;; master) IN_MASTER=yes;; esac
  fi
done

if [ "$IN_DEV" = yes ]; then
  echo
  echo "### dev node (SOURCE OF TRUTH — promote this verbatim; do NOT re-derive)"
  node_from_branch dev
  echo
  echo "### Verdict: node exists in dev."
  if [ "$IN_UAT" = no ] || [ "$IN_MASTER" = no ]; then
    echo "  -> Gap is PROMOTION (missing in uat/master). Rides the standard dev->uat->master config PRs."
  else
    echo "  -> Present in all envs. Nothing to do."
  fi
  exit 0
fi

echo
echo "### Verdict: ABSENT in dev -> derive a new node from monorepo usage, insert into dev."
echo
echo "### Insertion parent + sibling template (from working tree)"
python3 - "$CFG/privileges.json" "$PREFIX" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); prefix = sys.argv[2]
parts = prefix.split('.')
def find(n, t):
    if n.get('id') == t: return n
    for c in n.get('children', []):
        r = find(c, t)
        if r: return r
anc = None
for k in range(len(parts)-1, 0, -1):
    node = find(d, '.'.join(parts[:k]))
    if node: anc = ('.'.join(parts[:k]), node); break
if not anc:
    print("  (no ancestor found)"); sys.exit()
cand, node = anc
print(f"  insertion parent: {cand}")
print(f"  existing children: {[c['id'] for c in node.get('children', [])]}")
tail = parts[-1]
for c in node.get('children', []):
    if any(tok in c['id'].split('.')[-1] for tok in tail.split('_')):
        print(f"\n  sibling template ({c['id']}):")
        print(json.dumps(c, indent=2, ensure_ascii=False)); break
PY

echo
echo "### Monorepo usage — page routes (route.ts: path + permissionId)"
grep -rn -B4 "permissionId: '$PREFIX" "$MONO" --include='route.ts' 2>/dev/null \
  | grep -E "path:|permissionId:|breadcrumbName:" || echo "  (none)"
echo
echo "### Monorepo usage — action checks (useCheckPermission / *_PERMISSION_ID)"
grep -rnE "useCheckPermission\('$PREFIX|'$PREFIX[a-z_.]*'" "$MONO" \
  --include='*.ts' --include='*.tsx' 2>/dev/null | grep -v '/route.ts:' | sed 's/^/  /' | head -30 || echo "  (none)"
