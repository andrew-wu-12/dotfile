#!/usr/bin/env bash
# Snapshot the current homelab spec note into an immutable per-round file, so
# hl-pr-ready's drift gate can diff round-(N-1) against round-N to get exactly
# one round's change. Call this as the LAST step of hl-spec-init and
# hl-spec-sync, AFTER the note has been (re)written — so round-N.md ==
# end-of-round-N state.
#
# Usage: hl-spec-snapshot.sh <issue>-<slug>
# Prints the round number (zero-padded) it wrote.
set -euo pipefail

ID="${1:?usage: hl-spec-snapshot.sh <issue>-<slug>}"
SPECS="$HOME/personal/project-note/Homelab/2 - Specs"
NOTE="$SPECS/$ID.md"
RDIR="$SPECS/.rounds/$ID"

[ -f "$NOTE" ] || { echo "error: spec note not found: $NOTE" >&2; exit 1; }

mkdir -p "$RDIR"
COUNT=$(find "$RDIR" -maxdepth 1 -name 'round-*.md' | wc -l | tr -d ' ')
N=$(printf '%02d' "$((COUNT + 1))")
cp "$NOTE" "$RDIR/round-$N.md"
echo "$N"
