#!/usr/bin/env bash
# Snapshot the current spec note into an immutable per-round file, so the
# vault's 65-second auto-backup commits can't serve as round boundaries but
# these files can. Call this as the LAST step of /spec-init and /spec-sync,
# AFTER the note has been (re)written — so round-N.md == end-of-round-N state
# and /spec-drift can diff round-(N-1) against round-N to get exactly the change.
#
# Usage: spec-snapshot.sh <TICKET-ID>
# Prints the round number (zero-padded) it wrote.
set -euo pipefail

TICKET="${1:?usage: spec-snapshot.sh <TICKET-ID>}"
SPECS="$HOME/self/SyncObsidianNote/005-Sources/公司筆記/specs"
NOTE="$SPECS/$TICKET.md"
RDIR="$SPECS/.rounds/$TICKET"

[ -f "$NOTE" ] || { echo "error: spec note not found: $NOTE" >&2; exit 1; }

mkdir -p "$RDIR"
COUNT=$(find "$RDIR" -maxdepth 1 -name 'round-*.md' | wc -l | tr -d ' ')
N=$(printf '%02d' "$((COUNT + 1))")
cp "$NOTE" "$RDIR/round-$N.md"
echo "$N"
