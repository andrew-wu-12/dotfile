#!/bin/bash
# Live CI build-trace popup opened by trace_open_popup (picker ctrl-g).
# Arg: $1 worktree path. Waits for a keypress when done, then reopens the picker.

set -u

WT="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=tmux-build-trace-lib.sh
source "$SCRIPT_DIR/tmux-build-trace-lib.sh"

back_to_picker() {
  echo ""
  echo "(press any key to return to the picker)"
  read -rsn1
  # The picker can't open until this popup closes, so schedule it with a delay.
  tmux run-shell -b "$(printf 'sleep 0.3 && tmux display-popup -E -w 90%% -h 80%% %q || true' "$SCRIPT_DIR/tmux-window-picker.sh")"
  exit 0
}

trace_prepare "$WT" || back_to_picker

BRANCH=$(git -C "$WT" rev-parse --abbrev-ref HEAD 2>/dev/null)

SUBTITLE="$BRANCH"
if parsed=$(build_parse_ticket_branch "$BRANCH" 2>/dev/null); then
  SUBTITLE="${parsed%%$'\t'*} · $BRANCH"
fi

echo "🔍 Searching for recent builds for $SUBTITLE..."

specs=()
while IFS='|' read -r key job role label; do
  [ -n "$key" ] || continue
  role_branch=$(build_resolve_role "$role" "$WT" "$BRANCH")
  [ -n "$role_branch" ] || role_branch="$BRANCH"
  specs+=("$key|$job|$role_branch|$label")
done <<EOF
$BUILD_JOBS
EOF

TRACE_NOTIFY_SUBTITLE="$SUBTITLE"
trace_run "${specs[@]}"
rc=$?

if [ "$rc" -eq 1 ]; then
  echo "❌ No recent builds found for $SUBTITLE"
fi

back_to_picker
