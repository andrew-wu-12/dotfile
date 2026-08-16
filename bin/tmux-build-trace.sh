#!/bin/bash
# Live Jenkins build-trace window opened via ctrl-g in tmux-window-picker.sh's
# picker (`prefix w`, tmux-build-trace-lib.sh's trace_open_window). Not meant
# to be run directly.
#
# Same live progress-bar UX as trace-build.sh (search, then poll every 2s
# with an in-place redraw, then a final osascript notification) — extended
# to trace 4 fixed jobs instead of trace-build.sh's dynamic branch-name
# search: mop_console_monorepo_feature/dev against the ticket's own branch,
# mop_console_monorepo_epic_or_hotfix/uat against uat/<parent> (or the
# hotfix branch itself, resolved by tmux-build-trace-lib.sh).
#
# Args: $1 worktree path  $2 branch  $3 ticket number  $4 is_hotfix (true|false)
#
# The actual poll/redraw loop is tmux-build-trace-lib.sh's trace_run(),
# shared with ctrl-p's inline post-deploy trace in tmux-window-picker.sh —
# see that lib for why it isn't duplicated here.
#
# Ends by dropping into an interactive shell so the tmux window this runs in
# stays open showing the final results — the process this pane runs would
# otherwise exit and tmux would close the window out from under you.

set -u

WT="$1"
BRANCH="$2"
TICKET="$3"
IS_HOTFIX="$4"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=tmux-build-trace-lib.sh
source "$SCRIPT_DIR/tmux-build-trace-lib.sh"

# ~/.zshrc is a zsh script (oh-my-zsh, zstyle, etc.) — sourcing it directly
# into this bash script the way trace-build.sh does (it's #!/bin/zsh) blows
# up under `set -u`: .zshrc's own setup trips "ZSH_VERSION: unbound
# variable" partway through, which would abort this whole script on the
# spot. Fetch just the token from a real zsh subshell instead, same
# isolation trace_resolve_uat_branch already uses for the ticket-lib.sh call.
JENKINS_TOKEN=$(zsh -c 'source ~/.zshrc >/dev/null 2>&1; printf "%s" "$JENKINS_TOKEN"' 2>/dev/null)
if [ -z "$JENKINS_TOKEN" ]; then
  echo "Error: JENKINS_TOKEN is not set."
  exec "${SHELL:-zsh}"
fi

if [ "$IS_HOTFIX" = "true" ]; then
  UAT_BRANCH="$BRANCH"
else
  UAT_BRANCH=$(trace_resolve_uat_branch "$TICKET" "$IS_HOTFIX" "$BRANCH")
  [ -n "$UAT_BRANCH" ] || UAT_BRANCH="$BRANCH"
fi

echo "🔍 Searching for recent builds for $TICKET ($BRANCH / $UAT_BRANCH)..."

TRACE_NOTIFY_SUBTITLE="$TICKET · $BRANCH"
trace_run \
  "FEAT|mop_console_monorepo_feature|$BRANCH|feature build" \
  "DEV|mop_console_monorepo_dev|$BRANCH|one-dev deploy" \
  "EPIC|mop_console_monorepo_epic_or_hotfix|$UAT_BRANCH|epic/hotfix build" \
  "UAT|mop_console_monorepo_uat|$UAT_BRANCH|one-uat deploy"
rc=$?

if [ "$rc" -eq 1 ]; then
  echo "❌ No recent builds found for $TICKET ($BRANCH / $UAT_BRANCH)"
fi

echo ""
echo "(this window stays open — close it manually when you're done)"
exec "${SHELL:-zsh}"
