#!/bin/bash
# Status + switcher popup for the single MOP `yarn serve` (nx serve container,
# fixed port 4200 per apps/container/project.json) dev server. Bound to
# `prefix n` in .tmux.conf.
#
# The port is hardcoded so only one `yarn serve` can run at a time — rather
# than fight that, this keeps ONE server in a dedicated, always-hidden tmux
# window ("serve(mop-console-monorepo)") and lets you retarget which worktree
# it serves, without it ever occupying a visible pane.
#
# Bash 3.2-clean, styled after tmux-window-picker.sh (same fzf/catppuccin idiom).

set -u

SERVE_WIN_NAME="serve(mop-console-monorepo)"
PORT=4200
MOP_MONOREPO_PATH="${MOP_MONOREPO_PATH:-$HOME/project/mop-console-monorepo}"

TAB=$(printf '\t')
BOLD=$'\033[1m'
DIM=$'\033[2m'
RESET=$'\033[0m'

# session, window_id, pane_id of the serve window, or nothing. Suffix-matched
# (like tmux-dev-layout.sh's window_id_for) in case a marker prefix ever ends
# up on this window too.
find_serve_window() {
  tmux list-windows -a -F "#{session_name}${TAB}#{window_id}${TAB}#{window_name}" 2>/dev/null \
    | while IFS="$TAB" read -r sess winid wname; do
        case "$wname" in
          "$SERVE_WIN_NAME"|*" $SERVE_WIN_NAME")
            pane=$(tmux list-panes -t "$winid" -F '#{pane_id}' | head -1)
            printf '%s %s %s\n' "$sess" "$winid" "$pane"
            break
            ;;
        esac
      done
}

# Create it (idle, no server running yet) in the current session if missing.
ensure_serve_window() {
  local found; found=$(find_serve_window)
  [ -n "$found" ] && { printf '%s\n' "$found"; return 0; }
  local sess winid pane
  sess=$(tmux display-message -p '#S')
  winid=$(tmux new-window -d -n "$SERVE_WIN_NAME" -c "$MOP_MONOREPO_PATH" -P -F '#{window_id}' -t "$sess:")
  pane=$(tmux list-panes -t "$winid" -F '#{pane_id}' | head -1)
  printf '%s %s %s\n' "$sess" "$winid" "$pane"
}

SERVE_INFO=$(ensure_serve_window)
SERVE_WIN=$(printf '%s' "$SERVE_INFO" | cut -d' ' -f2)
SERVE_PANE=$(printf '%s' "$SERVE_INFO" | cut -d' ' -f3)

# --- status -----------------------------------------------------------------

current_target() {
  tmux show-option -w -t "$SERVE_WIN" -v @serve_target 2>/dev/null
}

# Sets $STATUS (offline|building|online|error) and, when STATUS=error,
# $ERR_DETAIL (last few non-blank lines of the compiler error, for the card
# body — the point of this popup's ctrl-x/ctrl-v/error-line additions is that
# the user shouldn't have to go hunt down the hidden serve pane just to see
# why the build broke).
compute_status() {
  local cur cmd tail http
  ERR_DETAIL=""
  cur=$(current_target)
  if [ -z "$cur" ]; then STATUS=offline; return; fi

  cmd=$(tmux display-message -p -t "$SERVE_PANE" '#{pane_current_command}' 2>/dev/null)
  case "$cmd" in zsh|bash|sh) STATUS=offline; return ;; esac

  tail=$(tmux capture-pane -p -t "$SERVE_PANE" -S -80 2>/dev/null)
  http=$(curl -s -o /dev/null --max-time 1 -w '%{http_code}' "http://localhost:$PORT" 2>/dev/null)

  if printf '%s\n' "$tail" | grep -qiE 'failed to compile|ERROR in '; then
    STATUS=error
    # Raw tail lines are mostly source-context noise (` 5 | import ...`) — grab
    # the actual "ERROR in <file>", its reason line, and the summary count
    # instead, confirmed against a real `yarn serve` compile-error run.
    ERR_DETAIL=$(printf '%s\n' "$tail" \
      | grep -iE '^ERROR in |cannot find module|module not found:|^Found [0-9]+ error' \
      | tail -4)
  elif printf '%s\n' "$tail" | grep -qi 'compiled successfully' && [ "$http" = "200" ]; then
    STATUS=online
  else
    STATUS=building
  fi
}

status_dot() {
  case "$STATUS" in
    online)   printf '\033[38;2;166;227;161m\xe2\x97\x8f\033[0m' ;;  # green
    building) printf '\033[38;2;249;226;175m\xe2\x97\x8f\033[0m' ;;  # yellow
    error)    printf '\033[38;2;243;139;168m\xe2\x97\x8f\033[0m' ;;  # red
    *)        printf '\033[38;2;127;132;156m\xe2\x97\x8f\033[0m' ;;  # grey
  esac
}

target_label() {  # $1 = worktree path
  local dir="$1" name branch
  [ -z "$dir" ] && { printf 'none'; return; }
  if [ "$dir" = "$MOP_MONOREPO_PATH" ]; then name="main"; else name=$(basename "$dir"); fi
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
  printf '%s (%s)' "$name" "${branch:-?}"
}

list_file=$(mktemp)
trap 'rm -f "$list_file"' EXIT

mocha="--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,\
header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,fg+:#cdd6f4,\
prompt:#cba6f7,hl+:#f38ba8,border:#585b70"

# Looped so every action (view log, stop, restart, switch) drops you back
# into an up-to-date picker instead of closing the popup — Esc/empty
# selection is the only way out.
while true; do
  compute_status
  CUR_TARGET=$(current_target)

  # fzf takes over the alternate screen, so anything printed to plain stdout
  # before it launches is hidden for fzf's entire run — the status has to go
  # through fzf's own --header, not a bare printf, or it's never actually seen.
  HEADER=$(printf ' %s %-9s serving: %-30s  http://localhost:%s\n enter:switch  ctrl-r:restart  ctrl-x:stop  ctrl-v:view log' "$(status_dot)" "$STATUS" "$(target_label "$CUR_TARGET")" "$PORT")

  # --- candidate list ---------------------------------------------------
  #
  # Cards follow tmux-window-picker.sh's style: a bold header line (target
  # label) plus, for whichever target is currently served, a dim status body
  # line — so the live state sits on the card itself instead of a separate
  # preview pane (which had nothing to show whenever the server was idle).
  : > "$list_file"

  # Written to a file, not a variable: bash silently drops NUL bytes from
  # variables, and more importantly here we need the loop's writes to survive
  # past the pipe-induced subshell.
  git -C "$MOP_MONOREPO_PATH" worktree list --porcelain 2>/dev/null | {
    path=""
    while IFS= read -r line; do
      case "$line" in
        worktree\ *) path="${line#worktree }" ;;
        branch\ *)
          record="${path}${TAB}${BOLD}$(target_label "$path")${RESET}"
          if [ "$path" = "$CUR_TARGET" ]; then
            status_line=$(printf '%s %s   http://localhost:%s' "$(status_dot)" "$STATUS" "$PORT")
            record="${record}
  ${status_line}"
            if [ "$STATUS" = "error" ] && [ -n "$ERR_DETAIL" ]; then
              while IFS= read -r errline; do
                [ -n "$errline" ] && record="${record}
  ${DIM}${errline}${RESET}"
              done <<EOF
$ERR_DETAIL
EOF
            fi
          fi
          printf '%s\0' "$record" >> "$list_file"
          ;;
        "") path="" ;;
      esac
    done
  }

  if [ ! -s "$list_file" ]; then
    printf '%s\n\nNo MOP worktrees found.\n' "$HEADER"
    read -r -p "Press enter to close..." _
    exit 0
  fi

  result=$(fzf \
    --read0 \
    --ansi \
    --gap=1 \
    --delimiter="$TAB" \
    --with-nth=2 \
    --layout=reverse \
    --border=rounded \
    --header="$HEADER" \
    --header-first \
    --prompt='serve ❯ ' \
    --pointer='▶' \
    --expect=ctrl-r,ctrl-x,ctrl-v \
    $mocha < "$list_file") || exit 0

  [ -z "$result" ] && exit 0

  # --expect prepends the pressed key as its own line (empty for a plain
  # Enter), ahead of the selected card — so the card's header line, which
  # used to be line 1, is now line 2. Body lines (status/error lines) have
  # no tab.
  KEY=$(printf '%s\n' "$result" | sed -n '1p')
  first_line=$(printf '%s\n' "$result" | sed -n '2p')
  TARGET=$(printf '%s' "$first_line" | cut -d"$TAB" -f1)

  # --- stop / restart / view full log ------------------------------------
  #
  # These act on whatever is currently served (CUR_TARGET), independent of
  # which card happens to be highlighted — there's only ever one server.

  if [ "$KEY" = "ctrl-x" ]; then
    if [ -z "$CUR_TARGET" ]; then echo "Nothing is being served."; sleep 1; continue; fi
    echo "Stopping yarn serve…"
    tmux send-keys -t "$SERVE_PANE" C-c
    tmux set-option -w -t "$SERVE_WIN" -u @serve_target
    sleep 1
    continue
  fi

  if [ "$KEY" = "ctrl-v" ]; then
    if [ -z "$CUR_TARGET" ]; then echo "Nothing is being served."; sleep 1; continue; fi
    tmux capture-pane -p -t "$SERVE_PANE" -S -500 | less -R +G
    continue
  fi

  if [ "$KEY" = "ctrl-r" ]; then
    if [ -z "$CUR_TARGET" ]; then echo "Nothing is being served."; sleep 1; continue; fi
    TARGET="$CUR_TARGET"
  else
    [ -z "$TARGET" ] && continue
    [ "$TARGET" = "$CUR_TARGET" ] && continue
  fi

  # --- switch -------------------------------------------------------------

  echo "Stopping current server…"
  tmux send-keys -t "$SERVE_PANE" C-c
  for _ in $(seq 1 20); do
    cmd=$(tmux display-message -p -t "$SERVE_PANE" '#{pane_current_command}' 2>/dev/null)
    case "$cmd" in zsh|bash|sh) break ;; esac
    sleep 0.5
  done
  cmd=$(tmux display-message -p -t "$SERVE_PANE" '#{pane_current_command}' 2>/dev/null)
  case "$cmd" in
    zsh|bash|sh) : ;;
    *) tmux send-keys -t "$SERVE_PANE" C-c ;;
  esac

  echo "Starting yarn serve in $(target_label "$TARGET")…"
  tmux send-keys -t "$SERVE_PANE" "cd '$TARGET' && yarn serve" Enter
  tmux set-option -w -t "$SERVE_WIN" @serve_target "$TARGET"

  echo "Switched — refreshing status…"
  sleep 1
done
