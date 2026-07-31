#!/bin/zsh
# Claude Code notification hook for ticket worktrees. Registered globally in
# ~/.claude/settings.json for the Notification / Stop / UserPromptSubmit events,
# but self-guards to only act when the agent's cwd is inside a ticket worktree
# under $WORKTREE_ROOT.
#
# Side effects only: a macOS notification (osascript) + a tmux window marker.
# It MUST stay silent on stdout — Claude Code treats a Stop / UserPromptSubmit
# hook's stdout as extra context injected back into the conversation, so every
# command here redirects its output and the script only ever exits 0.
#
# Usage (from settings.json): tmux-agent-notify.sh <notification|stop|clear>

emulate -L zsh
set -u

event="${1:-}"

# Hook payload is JSON on stdin; cwd tells us where the agent is working.
input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$cwd" ] && cwd="$PWD"

worktree_root="${WORKTREE_ROOT:-$HOME/project/worktrees}"
case "$cwd" in
    "$worktree_root"/*) ;;
    *) exit 0 ;;   # not a ticket worktree — stay quiet
esac

# Canonical window name "<branch>(<repo>)", matching tmux-dev-layout.sh.
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root="$cwd"
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
common=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)
case "$common" in /*) ;; *) common="$root/$common" ;; esac
repo=${common:h:t}
canonical="${branch}(${repo})"
ticket=${root:t}

marker=""; title=""; msg=""; do_popup=0; sound="Glass"
session=""; window_id=""; term_app=""
case "$event" in
    notification)
        marker="🔴 "; do_popup=1
        title="🔴 $ticket needs you"
        msg=$(printf '%s' "$input" | jq -r '.message // "Waiting for input"' 2>/dev/null)
        ;;
    stop)
        marker="🟢 "; do_popup=1
        title="🟢 $ticket done"
        msg="Agent finished its turn"
        ;;
    clear)
        marker=""; do_popup=0
        ;;
    *) exit 0 ;;
esac

bundle_id_of() {
    lsappinfo info -only bundleid "$1" 2>/dev/null \
        | sed -n 's/.*"CFBundleIdentifier"="\([^"]*\)".*/\1/p'
}

# Bundle id of the macOS app hosting a pid. A tmux client is not itself an app,
# so walk up the process tree (tmux client -> login shell -> terminal GUI) until
# LaunchServices recognizes an ancestor. Empty if none does.
app_bundle_for_pid() {
    local p=$1 b n=0
    while [ -n "$p" ] && [ "$p" != "1" ] && [ "$p" != "0" ] && [ $n -lt 10 ]; do
        b=$(bundle_id_of "$p")
        [ -n "$b" ] && { printf '%s' "$b"; return 0; }
        p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
        n=$((n + 1))
    done
    return 1
}

# tmux window marker: rename the agent's window to "<marker><canonical>".
# TMUX_PANE is inherited from the pane where claude was launched; no-op if unset
# (e.g. a bare-terminal claude). Also suppress the OS popup when you are already
# looking at this window — you only want to be pinged about tickets elsewhere.
if [ -n "${TMUX_PANE:-}" ]; then
    win_active=$(tmux display -p -t "$TMUX_PANE" '#{window_active}' 2>/dev/null)
    sess_attached=$(tmux display -p -t "$TMUX_PANE" '#{session_attached}' 2>/dev/null)
    session=$(tmux display -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null)
    window_id=$(tmux display -p -t "$TMUX_PANE" '#{window_id}' 2>/dev/null)
    tmux rename-window -t "$TMUX_PANE" "${marker}${canonical}" >/dev/null 2>&1

    # Resolved unconditionally (not just for the suppression check below):
    # a click-to-focus action needs the terminal app's bundle id exactly when
    # the popup fires, i.e. when the window is NOT active.
    client_pid=$(tmux list-clients -F '#{client_pid}' -t "$session" 2>/dev/null | head -1)
    term_app=$(app_bundle_for_pid "${client_pid:-0}")

    # "Already looking at it" needs all three: window active, session attached,
    # AND the terminal app frontmost. tmux cannot see that you alt-tabbed to a
    # browser — the window stays active — so without the frontmost check the
    # popup is suppressed exactly when you are away and most need it.
    if [ "${win_active:-0}" = "1" ] && [ "${sess_attached:-0}" != "0" ]; then
        front_app=$(bundle_id_of "$(lsappinfo front 2>/dev/null)")
        if [ -n "$term_app" ] && [ "$term_app" = "$front_app" ]; then
            do_popup=0
        fi
    fi
fi

if [ "$do_popup" = "1" ]; then
    # Neutralize AppleScript string-literal terminators.
    msg=${msg//\\/ }; msg=${msg//\"/ }
    title=${title//\"/ }

    if command -v terminal-notifier >/dev/null 2>&1 \
        && [ -n "$session" ] && [ -n "$window_id" ] && [ -n "$term_app" ]; then
        # Click-to-focus: switch tmux to the originating session/window and
        # raise the terminal app. Window is targeted by id (stable), not name
        # (rewritten on every event with the 🔴/🟢 marker).
        execute="tmux switch-client -t '${session}' && tmux select-window -t '${window_id}' && osascript -e 'tell application id \"${term_app}\" to activate'"
        terminal-notifier -title "$title" -subtitle "$branch" -message "$msg" \
            -sound "$sound" -execute "$execute" >/dev/null 2>&1
    else
        osascript -e "display notification \"${msg}\" with title \"${title}\" subtitle \"${branch}\" sound name \"${sound}\"" >/dev/null 2>&1
    fi
fi

exit 0
