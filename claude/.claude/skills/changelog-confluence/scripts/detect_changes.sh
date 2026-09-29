#!/usr/bin/env bash
# Detect changed files under libs/** on the current branch and group them into
# candidate components. Run this from inside the monorepo working tree.
#
# Usage: detect_changes.sh [base]
#   base  Git ref to diff against (default: main). Uses three-dot (merge-base)
#         so we only see what THIS branch introduced, not later main activity.
#
# Output: JSON on stdout — { branch, base, components: [ ... ] }. Each component
# is a *suggestion* (grouped by the changed file's directory); the agent refines
# and confirms the grouping with the user before anything is published.
set -euo pipefail

BASE="${1:-main}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo '{"error":"not inside a git repository (run from the monorepo working tree)"}'
  exit 1
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
DIFF=$(git diff --name-status "${BASE}...HEAD" -- 'libs/' 2>/dev/null || true)

BRANCH="$BRANCH" BASE="$BASE" DIFF="$DIFF" python3 <<'PY'
import os, json, re

diff = os.environ.get("DIFF", "")
groups = {}  # key -> {name, dir, files}

def stem(name):
    # menuUtils.ts -> menuUtils, PhoneInput.test.tsx -> PhoneInput
    return name.split('.', 1)[0]

for line in diff.splitlines():
    parts = line.split('\t')
    if len(parts) < 2:
        continue
    status = parts[0][0]          # A / M / D / R ...
    path = parts[-1]              # for renames, last field is the new path

    marker = '/src/lib/'
    if marker in path:
        after = path.split(marker, 1)[1]
        if '/' not in after:
            # A single-file module sitting directly under src/lib (util-heavy
            # libs/shared) IS the component — name it after the file, not the
            # generic parent "lib", so the suggestion is usable as-is.
            key, cdir, name = path, path, stem(os.path.basename(path))
        else:
            cdir = os.path.dirname(path)
            key, name = cdir, os.path.basename(cdir)
    else:
        # libs change outside a src/lib tree — group by directory.
        cdir = os.path.dirname(path)
        key, name = cdir, os.path.basename(cdir)

    g = groups.setdefault(key, {"name": name, "dir": cdir, "files": []})
    g["files"].append({"path": path, "status": status})

out = []
for key, g in sorted(groups.items()):
    statuses = {f["status"] for f in g["files"]}
    is_new = statuses == {"A"}
    m = re.match(r'(libs/[^/]+(?:/[^/]+)*?)/src/', g["dir"] + '/')
    lib = m.group(1) if m else g["dir"].split('/src/')[0]
    out.append({
        "suggested_component": g["name"],
        "component_dir": g["dir"],
        "lib": lib,
        "is_new": is_new,
        "change_tag": "新增" if is_new else "調整",
        "files": g["files"],
    })

print(json.dumps({
    "branch": os.environ.get("BRANCH"),
    "base": os.environ.get("BASE"),
    "components": out,
}, ensure_ascii=False, indent=2))
PY
