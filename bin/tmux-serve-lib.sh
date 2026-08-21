# Shared dev-server helpers — sourced by tmux-window-picker.sh (bash, `prefix
# w`) and worktree-done.sh (zsh, `wtd`), so kept to syntax both shells
# understand: no bash arrays, no zsh-only glob modifiers.
#
# One dev server runs at a time (global constraint). Its tmux window is named
# "serve(<label>)" where label comes from WORKSPACE_SERVE_LABEL in the
# workspace config. serve_find_window matches any serve(*) window by pattern
# so it works regardless of which workspace is currently active.

# Returns "serve(<label>)" for a given label string.
serve_make_win_name() { printf 'serve(%s)\n' "$1"; }

# Prints "session window_id pane_id" for the hidden serve window, or nothing.
# Matches any window named serve(*) (with optional notification-marker prefix).
serve_find_window() {
  local tab sess winid wname pane
  tab=$(printf '\t')
  tmux list-windows -a -F "#{session_name}${tab}#{window_id}${tab}#{window_name}" 2>/dev/null \
    | while IFS="$tab" read -r sess winid wname; do
        case "$wname" in
          serve\(*\)|*" serve("*)
            pane=$(tmux list-panes -t "$winid" -F '#{pane_id}' | head -1)
            printf '%s %s %s\n' "$sess" "$winid" "$pane"
            break
            ;;
        esac
      done
}

# Creates (or finds and renames) the hidden serve window. Always prints
# "session window_id pane_id". $1 = workspace label for the window name.
serve_ensure_window() {
  local label="${1:-serve}" win_name found sess winid pane
  win_name=$(serve_make_win_name "$label")
  found=$(serve_find_window)
  if [ -n "$found" ]; then
    winid=$(printf '%s' "$found" | cut -d' ' -f2)
    tmux rename-window -t "$winid" "$win_name" 2>/dev/null
    printf '%s\n' "$found"
    return 0
  fi
  sess=$(tmux display-message -p '#S')
  winid=$(tmux new-window -d -n "$win_name" -c "$HOME" -P -F '#{window_id}' -t "$sess:")
  pane=$(tmux list-panes -t "$winid" -F '#{pane_id}' | head -1)
  printf '%s %s %s\n' "$sess" "$winid" "$pane"
}

# Reads @serve_target off window $1 (the hidden serve window's id).
serve_current_target() {
  tmux show-option -w -t "$1" -v @serve_target 2>/dev/null
}

# Sets $STATUS (offline|building|online|error) and, when STATUS=error,
# $ERR_DETAIL. Relies on caller having set $SERVE_WIN and $SERVE_PANE.
# The serve port is read from @serve_port on the serve window — set by the
# caller via `tmux set-option -w -t $SERVE_WIN @serve_port <port>` when
# starting a serve session. If unset, HTTP health-check is skipped and
# yarn-specific log patterns are used alone (status stays building unless
# they match).
serve_compute_status() {
  local cur cmd tail http port
  ERR_DETAIL=""

  if [ -z "${SERVE_WIN:-}" ]; then STATUS=offline; return; fi
  cur=$(serve_current_target "$SERVE_WIN")
  if [ -z "$cur" ]; then STATUS=offline; return; fi

  cmd=$(tmux display-message -p -t "$SERVE_PANE" '#{pane_current_command}' 2>/dev/null)
  case "$cmd" in zsh|bash|sh) STATUS=offline; return ;; esac

  tail=$(tmux capture-pane -p -t "$SERVE_PANE" -S -80 2>/dev/null)
  port=$(tmux show-option -w -t "$SERVE_WIN" -v @serve_port 2>/dev/null)

  if printf '%s\n' "$tail" | grep -qiE 'failed to compile|ERROR in '; then
    STATUS=error
    ERR_DETAIL=$(printf '%s\n' "$tail" \
      | grep -iE '^ERROR in |cannot find module|module not found:|^Found [0-9]+ error' \
      | tail -4)
    return
  fi

  if [ -n "$port" ]; then
    http=$(curl -s -o /dev/null --max-time 1 -w '%{http_code}' "http://localhost:$port" 2>/dev/null)
    if printf '%s\n' "$tail" | grep -qi 'compiled successfully' && [ "$http" = "200" ]; then
      STATUS=online
    else
      STATUS=building
    fi
  else
    STATUS=building
  fi
}

serve_status_dot() {
  case "$STATUS" in
    online)   printf '\033[38;2;166;227;161m\xe2\x97\x8f\033[0m' ;;  # green
    building) printf '\033[38;2;249;226;175m\xe2\x97\x8f\033[0m' ;;  # yellow
    error)    printf '\033[38;2;243;139;168m\xe2\x97\x8f\033[0m' ;;  # red
    *)        printf '\033[38;2;127;132;156m\xe2\x97\x8f\033[0m' ;;  # grey
  esac
}

serve_target_label() {  # $1 = worktree/checkout path
  local dir="$1" name branch
  [ -z "$dir" ] && { printf 'none'; return; }
  name=$(basename "$dir")
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
  printf '%s (%s)' "$name" "${branch:-?}"
}

# If the serve window is currently targeting worktree path $1, stop the
# process and clear the target. Silent no-op otherwise. Used by wtd on teardown.
serve_stop_if_target() {
  local want="$1" info wid pane cur
  info=$(serve_find_window)
  [ -n "$info" ] || return 0
  wid=$(printf '%s' "$info" | cut -d' ' -f2)
  pane=$(printf '%s' "$info" | cut -d' ' -f3)
  cur=$(serve_current_target "$wid")
  [ "$cur" = "$want" ] || return 0
  echo "Stopping dev server (currently targeting this worktree)…"
  tmux send-keys -t "$pane" C-c
  tmux set-option -w -t "$wid" -u @serve_target
}
