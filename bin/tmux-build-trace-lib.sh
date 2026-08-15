# Shared Jenkins build-trace helpers for the mwt/wt MOP worktree workflow,
# triggered by ctrl-g in tmux-window-picker.sh's picker (`prefix w`).
#
# ctrl-g opens a new tmux popup (display-popup, same idiom as `prefix w`
# itself and `prefix Ctrl-G`'s lazygit popup) running tmux-build-trace.sh,
# which renders the same live progress-bar UX as trace-build.sh (draw_bar,
# ETA/duration, in-place redraw) — extended with the one-dev/one-uat jobs
# tmux-ticket-status.sh already checks (mop_console_monorepo_dev/uat), and
# that script's feature-vs-uat/parent branch resolution, so each job is
# queried against the branch that actually triggers it (feature/dev jobs
# against the ticket's own branch, epic/uat jobs against uat/<parent> — or
# the branch itself for a hotfix, which has no parent branch).
#
# A tmux client only shows one popup at a time, and the picker itself is
# already running inside one (`bind w display-popup ... tmux-window-picker.sh`
# in .tmux.conf) — calling `display-popup` again from inside that popup's own
# process would conflict with the one that's about to close underneath it.
# So the new popup isn't opened directly; it's scheduled via `tmux run-shell
# -b` with a short delay, decoupled from this pane, so it fires just after
# the picker's own popup has closed rather than racing it.
#
# An earlier version of this ran the trace as a detached background process
# with a sidecar cache file the picker polled for a one-line card status.
# That made the picker's card list go stale the instant the trace finished
# (fzf has no periodic-refresh hook — see tmux-window-picker.sh's ctrl-l
# history), which read as "the trace is broken" even when it wasn't. A live
# popup showing the actual loop has no such staleness problem, so that's all
# this does now.
#
# Bash 3.2-clean (no associative arrays / mapfile) so it can be sourced from
# tmux-window-picker.sh (bash). tmux-build-trace.sh (the window's own
# script) is invoked, never sourced, so it's free to use bash-only features
# like indirect expansion.

TRACE_JENKINS_URL="https://jenkins.morrison.express"
TRACE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Same check used by deploy-one.sh/deploy-i18n.sh/checkout-ticket.sh/
# tmux-ticket-status.sh — jenkins.morrison.express is only reachable over VPN.
trace_vpn_connected() {
  scutil --nc list 2>/dev/null | grep -q "Connected"
}

# Ticket number + hotfix flag from branch name $1, tab-separated
# ("MOP-1234<TAB>false"). Nonzero exit on no match (not a MOP feature/hotfix
# branch) with no output.
trace_parse_branch() {
  case "$1" in
    feature/MOP-*) printf '%s\tfalse\n' "${1#feature/}" ;;
    hotfix/MOP-*)  printf '%s\ttrue\n'  "${1#hotfix/}"  ;;
    *) return 1 ;;
  esac
}

# uat/<parent> for a feature ticket with an epic, or the branch itself for a
# hotfix (no parent branch to resolve) — same resolution tmux-ticket-status.sh
# uses for its one-uat/epic_or_hotfix checks. Shells out to zsh for the one
# JIRA-parent lookup since ticket-lib.sh's get_ticket_parent is zsh-only
# (1-based arrays, the (@s/-/) split flag).
trace_resolve_uat_branch() {
  local ticket="$1" is_hotfix="$2" branch="$3" parent
  if [ "$is_hotfix" = "true" ]; then
    printf '%s\n' "$branch"
    return 0
  fi
  parent=$(zsh -c "
    source '$TRACE_SCRIPT_DIR/ticket-lib.sh'
    source ~/.zshrc
    TICKET_DATA=\$(get_ticket_content '$ticket')
    PARENT_DATA=\$(get_ticket_parent \"\$TICKET_DATA\")
    get_from_json \"\$PARENT_DATA\" '.ticket_number'
  " 2>/dev/null)
  [ -n "$parent" ] && [ "$parent" != "null" ] || return 1
  printf 'uat/%s\n' "$parent"
}

# ctrl-g entry point: worktree path $1. Prints a user-facing message and
# returns nonzero when it can't proceed (VPN down / not a recognized
# branch) — the picker loops back into a refreshed popup in that case, same
# idiom it already uses for ctrl-s. On success, schedules the trace popup
# (see the file header for why it's scheduled rather than opened directly)
# and returns 0; the picker then exits, closing its own popup, which is what
# lets the scheduled one appear cleanly a beat later.
trace_open_popup() {
  local wt="$1" branch parsed ticket is_hotfix cmd popup_cmd

  if ! trace_vpn_connected; then
    echo "VPN required to trace builds."
    return 1
  fi

  branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)
  parsed=$(trace_parse_branch "$branch") || {
    echo "Not on a MOP feature/hotfix branch (current: $branch)."
    return 1
  }
  ticket="${parsed%%$'\t'*}"
  is_hotfix="${parsed##*$'\t'}"

  # `|| true` at the end is load-bearing: `tmux display-popup` exits nonzero
  # once the popup's shell exits (regardless of how you closed it), and
  # `run-shell -b` prints "<command> returned <code>" straight into whatever
  # pane was current when the job finished if the job's own exit status is
  # nonzero — which lands in your real terminal, well after the popup itself
  # is gone, looking like a stray error. Forcing this job's exit status to 0
  # silences that.
  cmd=$(printf '%q ' "$TRACE_SCRIPT_DIR/tmux-build-trace.sh" "$wt" "$branch" "$ticket" "$is_hotfix")
  popup_cmd=$(printf 'sleep 0.3 && tmux display-popup -E -w 90%% -h 80%% -d %q %s || true' "$wt" "$cmd")
  tmux run-shell -b "$popup_cmd"
}
