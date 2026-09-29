#!/usr/bin/env bash
# Snapshot the current homelab spec note into an immutable per-round file so hl-pr-ready's drift gate
# can diff round-(N-1) against round-N. Call as the LAST step of hl-spec-init / hl-spec-sync, AFTER the note
# is (re)written, so round-N.md == end-of-round-N state.
# Usage: hl-spec-snapshot.sh <issue>-<slug>   (prints the zero-padded round number it wrote)
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
