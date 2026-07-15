#!/usr/bin/env bash
# Emit the spec delta between two consecutive round snapshots, so /spec-drift only
# has to reason about what CHANGED (not the whole spec). round-NN.md == end-of-
# round-N state, so diffing round-(N-1) -> round-N is exactly one round's change.
#
# Usage:
#   round_diff.sh <MOP-XXXX>        # latest two rounds
#   round_diff.sh <MOP-XXXX> 3      # round-02 -> round-03
# Prints the compared filenames (to stderr) and a unified diff (to stdout).
# Exit 2 if fewer than two rounds exist (nothing to diff — run spec-sync first).
set -uo pipefail

TICKET="${1:?usage: round_diff.sh <MOP-XXXX> [N]}"
RDIR="$HOME/self/SyncObsidianNote/005-Sources/公司筆記/specs/.rounds/$TICKET"

[ -d "$RDIR" ] || { echo "error: no rounds dir for $TICKET ($RDIR)" >&2; exit 2; }

# Sorted round files (round-01.md, round-02.md, ...).
ROUNDS=()
while IFS= read -r f; do ROUNDS+=("$f"); done < <(find "$RDIR" -maxdepth 1 -name 'round-*.md' | sort)
COUNT=${#ROUNDS[@]}

if [ "$COUNT" -lt 2 ]; then
  echo "error: need >=2 rounds to diff (found $COUNT). Run spec-sync to create the next round." >&2
  exit 2
fi

if [ "$#" -ge 2 ]; then
  N=$(printf '%02d' "$2")
  P=$(printf '%02d' "$(( 10#$2 - 1 ))")
  NEW="$RDIR/round-$N.md"; OLD="$RDIR/round-$P.md"
  [ -f "$NEW" ] && [ -f "$OLD" ] || { echo "error: round-$P and/or round-$N not found" >&2; exit 2; }
else
  OLD="${ROUNDS[$((COUNT-2))]}"; NEW="${ROUNDS[$((COUNT-1))]}"
fi

echo "comparing: $(basename "$OLD") -> $(basename "$NEW")" >&2
diff -u "$OLD" "$NEW"
exit 0
