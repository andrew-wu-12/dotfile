#!/usr/bin/env bash
# Emit the spec delta between two round snapshots so callers reason only about what CHANGED.
# round-NN.md == end-of-round-N state, so round-(N-1) -> round-N is exactly one round's change.
# The two-round form exists for /mop-spec-post, whose baseline is the last round actually POSTED to Jira: when
# rounds 1-2 were never posted and round 3 is, the PM's delta spans 01 -> 03.
# Usage:
#   spec-round-diff.sh <MOP-XXXX>          # latest two rounds
#   spec-round-diff.sh <MOP-XXXX> 3        # round-02 -> round-03
#   spec-round-diff.sh <MOP-XXXX> 1 3      # round-01 -> round-03
# Compared filenames go to stderr, a unified diff to stdout. Exit 2 if the rounds don't exist (run mop-spec-sync first).
set -uo pipefail

TICKET="${1:?usage: spec-round-diff.sh <MOP-XXXX> [BASELINE] [TARGET]}"
RDIR="$HOME/personal/office-note/Specs/.rounds/$TICKET"

[ -d "$RDIR" ] || { echo "error: no rounds dir for $TICKET ($RDIR)" >&2; exit 2; }

ROUNDS=()
while IFS= read -r f; do ROUNDS+=("$f"); done < <(find "$RDIR" -maxdepth 1 -name 'round-*.md' | sort)
COUNT=${#ROUNDS[@]}

if [ "$COUNT" -lt 2 ]; then
  echo "error: need >=2 rounds to diff (found $COUNT). Run mop-spec-sync to create the next round." >&2
  exit 2
fi

if [ "$#" -ge 3 ]; then
  P=$(printf '%02d' "$(( 10#$2 ))")
  N=$(printf '%02d' "$(( 10#$3 ))")
  [ "$(( 10#$2 ))" -lt "$(( 10#$3 ))" ] || {
    echo "error: baseline round $2 must be older than target round $3" >&2; exit 2; }
elif [ "$#" -eq 2 ]; then
  N=$(printf '%02d' "$(( 10#$2 ))")
  P=$(printf '%02d' "$(( 10#$2 - 1 ))")
else
  P=""; N=""
fi

if [ -n "$N" ]; then
  NEW="$RDIR/round-$N.md"; OLD="$RDIR/round-$P.md"
  [ -f "$NEW" ] && [ -f "$OLD" ] || { echo "error: round-$P and/or round-$N not found" >&2; exit 2; }
else
  OLD="${ROUNDS[$((COUNT-2))]}"; NEW="${ROUNDS[$((COUNT-1))]}"
fi

echo "comparing: $(basename "$OLD") -> $(basename "$NEW")" >&2
diff -u "$OLD" "$NEW"
exit 0
