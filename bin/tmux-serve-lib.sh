# Shared MOP `yarn serve` helpers (nx serve container, fixed port 4200 per
# apps/container/project.json) — sourced by tmux-window-picker.sh (bash,
# `prefix w`) and worktree-done.sh (zsh, `wtd`), so kept to syntax both
# shells understand: no bash arrays, no zsh-only glob modifiers.
#
# The port is hardcoded so only one `yarn serve` can run at a time — rather
# than fight that, everything here funnels through ONE dedicated, always-
# hidden tmux window ("serve(mop-console-monorepo)") whose @serve_target
# window option records which worktree it's currently serving.

SERVE_WIN_NAME="serve(mop-console-monorepo)"
SERVE_PORT=4200
MOP_MONOREPO_PATH="${MOP_MONOREPO_PATH:-$HOME/project/mop-console-monorepo}"

# Absolute git-common-dir for path $1 (nonzero exit if $1 isn't inside a git
# repo). A linked worktree reports its common dir relative to itself, so
# resolve that case against $1's own toplevel.
serve_common_dir() {
  local base="$1" dir top
  dir=$(git -C "$base" rev-parse --git-common-dir 2>/dev/null) || return 1
  case "$dir" in
    /*) printf '%s\n' "$dir" ;;
    *)
      top=$(git -C "$base" rev-parse --show-toplevel 2>/dev/null) || return 1
      printf '%s/%s\n' "$top" "$dir"
      ;;
  esac
}

# True iff $1 is inside the same repository as $MOP_MONOREPO_PATH (its main
# checkout or any linked worktree) — compares resolved git-common-dir rather
# than string-matching paths, so it holds regardless of worktree layout.
serve_is_mop_path() {
  local mop_common path_common
  mop_common=$(serve_common_dir "$MOP_MONOREPO_PATH") || return 1
  path_common=$(serve_common_dir "$1") || return 1
  [ "$mop_common" = "$path_common" ]
}

# Prints "session window_id pane_id" for the hidden serve window, or
# nothing. Suffix-matched in case a notification marker prefix ever lands on
# this window too (it shouldn't, but tmux-dev-layout's own lookups guard the
# same way).
serve_find_window() {
  local tab sess winid wname pane
  tab=$(printf '\t')
  tmux list-windows -a -F "#{session_name}${tab}#{window_id}${tab}#{window_name}" 2>/dev/null \
    | while IFS="$tab" read -r sess winid wname; do
        case "$wname" in
          "$SERVE_WIN_NAME"|*" $SERVE_WIN_NAME")
            pane=$(tmux list-panes -t "$winid" -F '#{pane_id}' | head -1)
            printf '%s %s %s\n' "$sess" "$winid" "$pane"
            break
            ;;
        esac
      done
}

# Creates the hidden serve window (idle, no server running yet) in the
# current session if missing. Always prints "session window_id pane_id".
serve_ensure_window() {
  local found sess winid pane
  found=$(serve_find_window)
  if [ -n "$found" ]; then
    printf '%s\n' "$found"
    return 0
  fi
  sess=$(tmux display-message -p '#S')
  winid=$(tmux new-window -d -n "$SERVE_WIN_NAME" -c "$MOP_MONOREPO_PATH" -P -F '#{window_id}' -t "$sess:")
  pane=$(tmux list-panes -t "$winid" -F '#{pane_id}' | head -1)
  printf '%s %s %s\n' "$sess" "$winid" "$pane"
}

# Reads @serve_target off window $1 (the hidden serve window's id).
serve_current_target() {
  tmux show-option -w -t "$1" -v @serve_target 2>/dev/null
}

# Sets $STATUS (offline|building|online|error) and, when STATUS=error,
# $ERR_DETAIL (last few non-blank lines of the compiler error). Relies on
# the caller having set $SERVE_PANE and $SERVE_WIN.
serve_compute_status() {
  local cur cmd tail http
  ERR_DETAIL=""
  cur=$(serve_current_target "$SERVE_WIN")
  if [ -z "$cur" ]; then STATUS=offline; return; fi

  cmd=$(tmux display-message -p -t "$SERVE_PANE" '#{pane_current_command}' 2>/dev/null)
  case "$cmd" in zsh|bash|sh) STATUS=offline; return ;; esac

  tail=$(tmux capture-pane -p -t "$SERVE_PANE" -S -80 2>/dev/null)
  http=$(curl -s -o /dev/null --max-time 1 -w '%{http_code}' "http://localhost:$SERVE_PORT" 2>/dev/null)

  if printf '%s\n' "$tail" | grep -qiE 'failed to compile|ERROR in '; then
    STATUS=error
    ERR_DETAIL=$(printf '%s\n' "$tail" \
      | grep -iE '^ERROR in |cannot find module|module not found:|^Found [0-9]+ error' \
      | tail -4)
  elif printf '%s\n' "$tail" | grep -qi 'compiled successfully' && [ "$http" = "200" ]; then
    STATUS=online
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

serve_target_label() {  # $1 = worktree path
  local dir="$1" name branch
  [ -z "$dir" ] && { printf 'none'; return; }
  if [ "$dir" = "$MOP_MONOREPO_PATH" ]; then name="main"; else name=$(basename "$dir"); fi
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
  printf '%s (%s)' "$name" "${branch:-?}"
}

# If the hidden serve window is currently targeting worktree path $1, stop
# the process and clear the target. Silent no-op otherwise. Used by wtd on
# teardown (so `git worktree remove` never fights a running process whose
# cwd is inside the worktree being removed) and available to any ctrl-x-style
# caller.
serve_stop_if_target() {
  local want="$1" info wid pane cur
  info=$(serve_find_window)
  [ -n "$info" ] || return 0
  wid=$(printf '%s' "$info" | cut -d' ' -f2)
  pane=$(printf '%s' "$info" | cut -d' ' -f3)
  cur=$(serve_current_target "$wid")
  [ "$cur" = "$want" ] || return 0
  echo "Stopping yarn serve (currently targeting this worktree)…"
  tmux send-keys -t "$pane" C-c
  tmux set-option -w -t "$wid" -u @serve_target
}
