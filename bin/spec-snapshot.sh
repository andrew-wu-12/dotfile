#!/usr/bin/env bash
# Snapshot the current spec note into an immutable per-round file; the vault's 65-second auto-backup commits
# can't serve as round boundaries but these files can. Call as the LAST step of /mop-spec-init and /mop-spec-sync,
# AFTER the note is (re)written, so round-N.md == end-of-round-N state and /mop-spec-drift can diff
# round-(N-1) against round-N.
# Usage: spec-snapshot.sh <TICKET-ID>   (prints the zero-padded round number it wrote)
set -euo pipefail

TICKET="${1:?usage: spec-snapshot.sh <TICKET-ID>}"
SPECS="$HOME/personal/office-note/Specs"
NOTE="$SPECS/$TICKET.md"
RDIR="$SPECS/.rounds/$TICKET"

[ -f "$NOTE" ] || { echo "error: spec note not found: $NOTE" >&2; exit 1; }

mkdir -p "$RDIR"
COUNT=$(find "$RDIR" -maxdepth 1 -name 'round-*.md' | wc -l | tr -d ' ')
N=$(printf '%02d' "$((COUNT + 1))")
cp "$NOTE" "$RDIR/round-$N.md"
echo "$N"
