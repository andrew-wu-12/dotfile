#!/bin/zsh
# Required parameters
# @raycast.schemaVersion 1
# @raycast.title Combine Branches
# @raycast.mode fullOutput
#
# @raycast.icon 🔀
# @raycast.packageName Deploy One
# @raycast.argument1 {"type": "text", "placeholder": "feat-a feat-b feat-c [-d]" }
#
# Rebuild a disposable integration branch from a base branch by merging several
# feature branches into it.
#
# The integration branch is thrown away and recreated on every run, so it never
# drifts: it is always base + the current tip of each feature branch.
#
# Usage:
#   combine-branches.sh [options] <feature-branch>...
#
# Options:
#   -b, --base <branch>   base branch to build on            (default: main)
#   -n, --name <branch>   integration branch name            (default: integration/combined)
#   -l, --local           merge local branches (default: origin/<branch> after fetch)
#   -p, --no-push         build locally only, do not push
#   -h, --help            show this help
#
# Examples:
#   combine-branches.sh feature/MOP-1 feature/MOP-2 feature/MOP-3
#   combine-branches.sh -n integration/MOP-demo feature/MOP-1 feature/MOP-2
#   combine-branches.sh --base uat/MOP-99 feature/MOP-1 feature/MOP-2

emulate -L zsh
set -e

BASE="main"
INT_NAME="integration/combined"
USE_LOCAL=0
DO_PUSH=1
FEATURES=()

usage() {
    cat <<'EOF'
Rebuild a disposable integration branch from a base branch by merging several
feature branches into it.

Usage:
  combine-branches.sh [options] <feature-branch>...

Options:
  -b, --base <branch>   base branch to build on            (default: main)
  -n, --name <branch>   integration branch name            (default: integration/combined)
  -l, --local           merge local branches (default: origin/<branch> after fetch)
  -p, --no-push         build locally only, do not push
  -h, --help            show this help

Examples:
  combine-branches.sh feature/MOP-1 feature/MOP-2 feature/MOP-3
  combine-branches.sh -n integration/MOP-demo feature/MOP-1 feature/MOP-2
EOF
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--base)     BASE="$2"; shift 2 ;;
        -n|--name)     INT_NAME="$2"; shift 2 ;;
        -l|--local)    USE_LOCAL=1; shift ;;
        -p|--no-push)  DO_PUSH=0; shift ;;
        -h|--help)     usage 0 ;;
        -*)            echo "Unknown option: $1"; usage 1 ;;
        *)             FEATURES+=("$1"); shift ;;
    esac
done

if [[ ${#FEATURES[@]} -lt 1 ]]; then
    echo "Error: give at least one feature branch to combine."
    usage 1
fi

# Refuse to run on a dirty tree — we switch branches and could clobber work.
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: working tree is not clean. Commit or stash first."
    exit 1
fi

ORIGINAL_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
restore() { git checkout -q "$ORIGINAL_BRANCH" 2>/dev/null || true; }

if [[ $USE_LOCAL -eq 0 ]]; then
    echo "Fetching latest refs..."
    git fetch --prune origin
fi

# Resolve refs and verify they exist before we touch anything.
ref_for() { [[ $USE_LOCAL -eq 1 ]] && echo "$1" || echo "origin/$1"; }
BASE_REF="$(ref_for "$BASE")"
git rev-parse --verify -q "$BASE_REF" >/dev/null || { echo "Error: base ref '$BASE_REF' not found."; exit 1; }
for f in "${FEATURES[@]}"; do
    r="$(ref_for "$f")"
    git rev-parse --verify -q "$r" >/dev/null || { echo "Error: feature ref '$r' not found."; exit 1; }
done

echo "Rebuilding '$INT_NAME' from '$BASE_REF'..."
git checkout -q -B "$INT_NAME" "$BASE_REF"

# Merge each feature in turn so a conflict names the exact culprit branch.
for f in "${FEATURES[@]}"; do
    r="$(ref_for "$f")"
    echo "  merging $r ..."
    if ! git merge --no-ff --no-edit "$r"; then
        echo ""
        echo "CONFLICT while merging '$r' into '$INT_NAME'."
        echo "Conflicting files:"
        git diff --name-only --diff-filter=U | sed 's/^/  - /'
        echo ""
        echo "Resolve manually, or aborting now to leave your tree clean:"
        git merge --abort
        restore
        exit 1
    fi
done

echo "Combined branch built: $(git rev-parse --short HEAD)"

if [[ $DO_PUSH -eq 1 ]]; then
    echo "Force-pushing '$INT_NAME'..."
    git push --force-with-lease origin "$INT_NAME"
fi

restore

echo "Done. Deploy with: deploy-one.sh $INT_NAME"
