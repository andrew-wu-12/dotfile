#!/bin/bash
# Live CI build-trace window opened via ctrl-g in tmux-window-picker.sh's
# picker (`prefix w`, tmux-build-trace-lib.sh's trace_open_popup). Not meant
# to be run directly.
#
# Generic across any repo with a .tmux-build.conf (see tmux-build-config.sh):
# resolves the worktree's config, resolves each configured job's branch role
# (current|base|jira_parent), then runs tmux-build-trace-lib.sh's shared
# trace_run() — the actual poll/redraw core, also used by ctrl-p's inline
# post-deploy trace in tmux-window-picker.sh.
#
# Arg: $1 worktree path
#
# Ends by dropping into an interactive shell so the tmux window this runs in
# stays open showing the final results — the process this pane runs would
# otherwise exit and tmux would close the window out from under you.

set -u

WT="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=init-lib.sh
source "$SCRIPT_DIR/init-lib.sh"
# shellcheck source=tmux-build-trace-lib.sh
source "$SCRIPT_DIR/tmux-build-trace-lib.sh"

build_config_load "$WT"

if [ -z "${BUILD_BACKEND:-}" ]; then
  echo "Error: no .tmux-build.conf found for $WT"
  exec "${SHELL:-zsh}"
fi

if [ -z "${BUILD_JOBS:-}" ]; then
  echo "Error: .tmux-build.conf for $WT sets no BUILD_JOBS"
  exec "${SHELL:-zsh}"
fi

BACKEND_MODULE="$SCRIPT_DIR/tmux-build-backend-${BUILD_BACKEND}.sh"
if [ ! -f "$BACKEND_MODULE" ]; then
  echo "Error: no backend module for BUILD_BACKEND=$BUILD_BACKEND ($BACKEND_MODULE)"
  exec "${SHELL:-zsh}"
fi
# shellcheck source=/dev/null
source "$BACKEND_MODULE"

BRANCH=$(git -C "$WT" rev-parse --abbrev-ref HEAD 2>/dev/null)

# Each backend module may define "${BUILD_BACKEND}_ensure_auth" to fetch
# whatever credential it needs (e.g. jenkins_ensure_auth sets $JENKINS_TOKEN,
# forgejo_ensure_auth sets $FORGEJO_TOKEN) and return nonzero if missing.
# Backends that need no auth (a public CI, say) just don't define one.
AUTH_FN="${BUILD_BACKEND}_ensure_auth"
if command -v "$AUTH_FN" >/dev/null 2>&1; then
  if ! "$AUTH_FN"; then
    echo "Error: no credential found for ${BUILD_CRED_NAME:-$BUILD_BACKEND}"
    exec "${SHELL:-zsh}"
  fi
fi

# Nicer notification subtitle when this is a ticket branch (MOP); falls back
# to the plain branch name for repos with no ticket scheme.
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

echo ""
echo "(this window stays open — close it manually when you're done)"
exec "${SHELL:-zsh}"
