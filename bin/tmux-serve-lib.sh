# Shared dev-server helpers sourced by tmux-window-picker.sh (bash) and worktree-done.sh (zsh), so kept to
# syntax both shells understand: no bash arrays, no zsh-only glob modifiers.
# One dev server runs at a time; its window is "serve(<label>)" (label = WORKSPACE_SERVE_LABEL), and
# serve_find_window matches any serve(*) window so it works whichever workspace is active.

serve_make_win_name() { printf 'serve(%s)\n' "$1"; }

# Prints "session window_id pane_id" for the hidden serve window (serve(*), optional marker prefix), or nothing.
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

# Creates (or finds and renames) the hidden serve window; prints "session window_id pane_id".
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

serve_current_target() {
  tmux show-option -w -t "$1" -v @serve_target 2>/dev/null
}

# Sets $STATUS (offline|building|online|error) and, on error, $ERR_DETAIL; needs $SERVE_WIN and $SERVE_PANE.
# The port comes from @serve_port on the serve window (set by the caller when starting serve); if unset the
# HTTP check is skipped and status stays building unless the yarn log patterns match.
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
    if printf '%s\n' "$tail" | grep -q '\[host\] 100% done' && [ "$http" = "200" ]; then
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

# If the serve window targets worktree path $1, stop it and clear the target (used by wtd on teardown).
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
