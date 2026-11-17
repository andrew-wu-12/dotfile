#!/bin/bash
# CLI over tmux-serve-lib.sh for scripts and agents that drive the single dev server without the picker.
#
#   tmux-serve.sh status              print "<target>\t<status>\t<cmd>" (target empty when nothing is served)
#   tmux-serve.sh start <path> [cmd]  serve worktree <path> with [cmd], default WORKSPACE_SERVE_CMD from its .workspace.conf
#   tmux-serve.sh wait [seconds]      block until online (exit 0), compile error (exit 1, details on stderr), or timeout (exit 2)
#   tmux-serve.sh lock <owner> [secs] take the agent serve lock, waiting up to [secs] (default 3600); exit 2 on timeout
#   tmux-serve.sh unlock <owner>      release the lock if <owner> holds it

set -u

SERVE_LOCK_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-serve.lock"
SERVE_LOCK_STALE=7200

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

lock_owner() { cat "$SERVE_LOCK_DIR/owner" 2>/dev/null; }

lock_age() {
  local since
  since=$(stat -f %m "$SERVE_LOCK_DIR" 2>/dev/null || stat -c %Y "$SERVE_LOCK_DIR" 2>/dev/null) || { echo 0; return; }
  echo $(( $(date +%s) - since ))
}

cmd_lock() {
  local owner timeout waited=0 announced=0
  [ $# -ge 1 ] || { echo "usage: tmux-serve.sh lock <owner> [secs]" >&2; exit 64; }
  owner="$1"; timeout="${2:-3600}"
  mkdir -p "$(dirname "$SERVE_LOCK_DIR")"
  while :; do
    if mkdir "$SERVE_LOCK_DIR" 2>/dev/null; then
      printf '%s\n' "$owner" > "$SERVE_LOCK_DIR/owner"
      echo locked
      return 0
    fi
    if [ "$(lock_owner)" = "$owner" ]; then
      echo locked
      return 0
    fi
    if [ "$(lock_age)" -ge "$SERVE_LOCK_STALE" ]; then
      echo "Taking over stale lock from $(lock_owner)" >&2
      rm -rf "$SERVE_LOCK_DIR"
      continue
    fi
    [ "$waited" -ge "$timeout" ] && { echo "timeout (held by $(lock_owner))"; return 2; }
    [ "$announced" = 0 ] && { echo "waiting for lock held by $(lock_owner)" >&2; announced=1; }
    sleep 10
    waited=$((waited + 10))
  done
}

cmd_unlock() {
  [ $# -ge 1 ] || { echo "usage: tmux-serve.sh unlock <owner>" >&2; exit 64; }
  if [ "$(lock_owner)" = "$1" ]; then
    rm -rf "$SERVE_LOCK_DIR"
    echo unlocked
  else
    echo "not held by $1"
  fi
}

case "${1:-}" in
  status) cmd_status ;;
  start) shift; cmd_start "$@" ;;
  wait) shift; cmd_wait "$@" ;;
  lock) shift; cmd_lock "$@" ;;
  unlock) shift; cmd_unlock "$@" ;;
  *) sed -n '4,8p' "$0" | sed 's/^# //' >&2; exit 64 ;;
esac
