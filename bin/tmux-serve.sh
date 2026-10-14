#!/bin/bash
# CLI over tmux-serve-lib.sh for scripts and agents that drive the single dev server without the picker.
#
#   tmux-serve.sh status              print "<target>\t<status>\t<cmd>" (target empty when nothing is served)
#   tmux-serve.sh start <path> [cmd]  serve worktree <path> with [cmd], default WORKSPACE_SERVE_CMD from its .workspace.conf
#   tmux-serve.sh wait [seconds]      block until online (exit 0), compile error (exit 1, details on stderr), or timeout (exit 2)

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tmux-serve-lib.sh
source "$SCRIPT_DIR/tmux-serve-lib.sh"
# shellcheck source=tmux-build-config.sh
source "$SCRIPT_DIR/tmux-build-config.sh"

load_serve_window() {
  SERVE_INFO=$(serve_find_window)
  SERVE_WIN=$(printf '%s' "$SERVE_INFO" | cut -d' ' -f2)
  SERVE_PANE=$(printf '%s' "$SERVE_INFO" | cut -d' ' -f3)
}

cmd_status() {
  local target="" cmd=""
  load_serve_window
  serve_compute_status
  if [ -n "$SERVE_WIN" ]; then
    target=$(serve_current_target "$SERVE_WIN")
    cmd=$(tmux show-option -w -t "$SERVE_WIN" -v @serve_cmd 2>/dev/null)
  fi
  printf '%s\t%s\t%s\n' "$target" "$STATUS" "$cmd"
}

cmd_start() {
  local target serve_cmd
  [ $# -ge 1 ] || { echo "usage: tmux-serve.sh start <path> [cmd]" >&2; exit 64; }
  target=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || { echo "Not a git worktree: $1" >&2; exit 1; }
  workspace_config_load "$target"
  serve_cmd="${2:-${WORKSPACE_SERVE_CMD:-yarn serve}}"
  serve_start "$target" "$serve_cmd" "${WORKSPACE_SERVE_LABEL:-$(basename "$target")}" "${WORKSPACE_SERVE_PORT:-}"
  printf '%s\t%s\n' "$target" "$serve_cmd"
}

cmd_wait() {
  local timeout="${1:-600}" waited=0
  load_serve_window
  while [ "$waited" -lt "$timeout" ]; do
    serve_compute_status
    case "$STATUS" in
      online) echo online; return 0 ;;
      error) echo error; printf '%s\n' "$ERR_DETAIL" >&2; return 1 ;;
      offline) [ "$waited" -ge 10 ] && { echo offline; return 1; } ;;
    esac
    sleep 5
    waited=$((waited + 5))
  done
  echo timeout
  return 2
}

case "${1:-}" in
  status) cmd_status ;;
  start) shift; cmd_start "$@" ;;
  wait) shift; cmd_wait "$@" ;;
  *) sed -n '4,6p' "$0" | sed 's/^# //' >&2; exit 64 ;;
esac
