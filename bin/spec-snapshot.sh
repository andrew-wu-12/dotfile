#!/usr/bin/env bash
# Snapshot the current spec note into an immutable per-round file. Vault git history can't serve as a round
# boundary (office-note auto-commits every ~65s); these files can. Call as the LAST step of spec-init and
# spec-sync, AFTER the note is (re)written, so round-N.md == end-of-round-N state and spec-drift can diff
# round-(N-1) against round-N.
# Usage: spec-snapshot.sh <SPECS-DIR> <ID>   (prints the zero-padded round number it wrote)
set -euo pipefail

SPECS="${1:?usage: spec-snapshot.sh <SPECS-DIR> <ID>}"
ID="${2:?usage: spec-snapshot.sh <SPECS-DIR> <ID>}"
NOTE="$SPECS/$ID.md"
RDIR="$SPECS/.rounds/$ID"

[ -f "$NOTE" ] || { echo "error: spec note not found: $NOTE" >&2; exit 1; }

mkdir -p "$RDIR"
COUNT=$(find "$RDIR" -maxdepth 1 -name 'round-*.md' | wc -l | tr -d ' ')
N=$(printf '%02d' "$((COUNT + 1))")
cp "$NOTE" "$RDIR/round-$N.md"
echo "$N"
