#!/bin/bash
# Vertical window picker with following extracfunctions:+ : an fzf popup listing every
# tmux window across all sessions as a vertical stack of cards.
#   enter   switch to the highlighted window (across sessions) and exit
#
#   MOP yarn-serve control
#   ctrl-s  set the highlighted window's worktree as the yarn-serve target
#           (does NOT switch — "check out the window, decide separately
#           whether to serve from it")
#   ctrl-r  restart whatever is currently served
#   ctrl-x  stop whatever is currently served
#   ctrl-v  view the full serve log
#
#   build/trace (any worktree with a .tmux-build.conf — see
#   tmux-build-config.sh; not MOP-specific)
#   ctrl-g  open a new tmux popup tracing this worktree's configured CI jobs
#           with a live trace-build.sh-style progress bar, gated on VPN only
#           when the resolved config asks for it — see
#           tmux-build-trace-lib.sh. Exits this popup first (a tmux client
#           only shows one popup at a time), then the trace popup opens a
#           beat later.
#
#   MOP jenkins deploy control (MOP-only, unlike ctrl-g above)
#   ctrl-p  deploy the highlighted worktree's ticket: VPN/worktree/branch
#           gated (its own MOP-specific check, separate from ctrl-g's
#           config-driven one), then two decoupled fzf steps — 1) which
#           branch (the ticket's own branch, or uat/<parent>, deduped to one
#           line for a hotfix where they're the same), 2) which job(s)
#           (dev/uat/one) — whichever branch you picked in step 1 is passed
#           as BRANCH to every job step 2 fires, via tmux-deploy-lib.sh's
#           deploy_trigger_job, then an inline trace_run over just the
#           job(s) triggered — right here in this same popup pane (no popup
#           swap, unlike ctrl-g), then back to the picker. See deploy_run()
#           below. (ctrl-d was tried first but closes the popup/window
#           instead of reaching fzf.)
#   esc     cancel
#
# ctrl-s/ctrl-r/ctrl-x/ctrl-v/ctrl-p act and loop back into a refreshed
# picker; enter/ctrl-g/esc are the only ways out (ctrl-g schedules the trace
# popup and exits, rather than switching to a plain window, but it's still
# an exit). This used to be two separate popups (`prefix w` for switching,
# `prefix n` for serve control via tmux-serve-popup.sh) — merged here since
# both start from "which window am I looking at," and serve-targeting only
# makes sense for a worktree that already has one open. Shared serve helpers
# live in tmux-serve-lib.sh (also sourced by worktree-done.sh); shared
# build-trace helpers (also used by ctrl-p) live in tmux-build-trace-lib.sh;
# shared Jenkins-trigger helpers live in tmux-deploy-lib.sh.
#
# Each card is a multi-line fzf item (fzf --read0, fzf >= 0.44 required for
# multi-line item rendering): a bold header line ("session │ window-name",
# window-name already carrying any 🔴/🟢 marker from tmux-agent-notify.sh),
# then optionally a dim ticket-title line (from @ticket_title, set by
# worktree-ticket.sh) and/or a serve status/marker line. The header is
# deliberately the LAST tab-delimited field (session, window_id, MOP
# worktree path, build/trace worktree path, header) rather than the first
# four: --with-nth/--delimiter split fields across the whole multi-line
# record, not per physical line, so any body text appended after the header
# (title, status lines) has to land after the last tab or it silently falls
# outside --with-nth's display range. fzf's multi-line matching searches the
# whole card as a side effect of this layout.
#
# Two separate worktree-path fields exist because ctrl-g/build-trace is
# universal (any repo with a .tmux-build.conf) while ctrl-s/ctrl-p/preview
# stay MOP-only: field {3} is the MOP worktree path (empty for non-MOP
# windows), field {4} is the build/trace worktree path (empty for non-
# worktree windows, set for ANY mwt/wt worktree including MOP's).
#
# The preview pane (right 60%) runs tmux-ticket-status.sh against the
# highlighted card's MOP worktree path (field {3}, blank/placeholder for
# non-MOP windows) — see PREVIEW_CMD below. tmux-ticket-status.sh caches its
# report per worktree, so re-invoking it on every highlighted row is just a
# cache read, not a live fetch. ctrl-l busts the cache for the highlighted
# card and refreshes the preview in place — see the --bind below.
#
# The hidden serve window itself never appears in the list — it's plumbing,
# not somewhere to jump to.
#
# Bash 3.2-clean (no associative arrays / mapfile).

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tmux-serve-lib.sh
source "$SCRIPT_DIR/tmux-serve-lib.sh"
# shellcheck source=tmux-build-trace-lib.sh
source "$SCRIPT_DIR/tmux-build-trace-lib.sh"
# shellcheck source=tmux-deploy-lib.sh
source "$SCRIPT_DIR/tmux-deploy-lib.sh"

WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/project/worktrees}"

TAB=$(printf '\t')
BOLD=$'\033[1m'
DIM=$'\033[38;2;127;132;156m'  # catppuccin mocha "overlay1"
RESET=$'\033[0m'

mocha="--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,\
header:#f5e0dc,info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,fg+:#cdd6f4,\
prompt:#cba6f7,hl+:#f38ba8,border:#585b70"

# {3} is the worktree path field (empty for non-MOP-worktree windows) — fzf
# quotes placeholder substitutions itself, so this is safe as-is. Re-invoked
# on every highlighted row (including transient ones while scrolling), but
# tmux-ticket-status.sh caches its report per worktree, so this is a cache
# read on every cursor move, not a live fetch — see tmux-ticket-status.sh.
PREVIEW_CMD='wt={3}; if [ -z "$wt" ]; then printf "(not a MOP ticket window)\n"; else ~/bin/tmux-ticket-status.sh "$wt"; fi'

# ctrl-l busts the highlighted card's ticket-status cache, then refreshes
# the preview — the follow-up preview invocation (PREVIEW_CMD above) is a
# plain cache miss at that point, so it re-fetches live and repopulates.
# No-op for non-MOP windows: --reload "" resolves nothing and exits quietly.
RELOAD_BIND='ctrl-l:execute-silent(~/bin/tmux-ticket-status.sh --reload {3})+refresh-preview'

SERVE_INFO=$(serve_ensure_window)
SERVE_WIN=$(printf '%s' "$SERVE_INFO" | cut -d' ' -f2)
SERVE_PANE=$(printf '%s' "$SERVE_INFO" | cut -d' ' -f3)

list_file=$(mktemp)
trap 'rm -f "$list_file"' EXIT

# --- start/stop actions on the hidden serve window ---------------------

serve_switch_to() {  # $1 = worktree path to serve
  local target="$1" cmd
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

  tmux send-keys -t "$SERVE_PANE" "cd '$target' && yarn serve" Enter
  tmux set-option -w -t "$SERVE_WIN" @serve_target "$target"

  sleep 1
}

serve_stop_current() {
  tmux send-keys -t "$SERVE_PANE" C-c
  tmux set-option -w -t "$SERVE_WIN" -u @serve_target
  sleep 1
}

# --- ctrl-p: deploy ------------------------------------------------------
#
# Same three gates as ctrl-g's trace_open_popup (VPN, MOP worktree, feature/
# hotfix branch). Two-step selection, decoupled: step 1 picks WHICH branch to
# deploy (the ticket's own branch, or uat/<parent> via trace_resolve_uat_branch
# — deduped to one line when they're identical, i.e. a hotfix with no parent
# to resolve), step 2 picks WHICH job(s) to fire (dev/uat/one). Whichever
# branch was picked in step 1 is passed as BRANCH to every job step 2
# triggers — jobs no longer have a branch baked in, unlike the old single-step
# version where "dev" always meant the ticket's own branch and "uat" always
# meant uat/<parent>. Both resolved branches are computed unconditionally up
# front (one extra Jira round-trip per invocation) since step 1 has to show
# both options before step 2 even exists. Triggers on step 2's selection (no
# extra confirm beyond that — same as ctrl-s/ctrl-r/ctrl-x), then runs
# trace_run inline in this same popup pane over just the job(s) just
# triggered — no popup swap like ctrl-g, since deploy_run returns control to
# the picker's own while-loop afterward.
deploy_run() {
  local wt="$1" branch parsed ticket is_hotfix uat_branch
  local branch_opts branch_choice job_choice
  local specs=()

  if ! trace_vpn_connected; then
    echo "VPN required to trigger deploy."; sleep 1; return
  fi

  branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)
  parsed=$(trace_parse_branch "$branch") || {
    echo "Not on a MOP feature/hotfix branch (current: $branch)."; sleep 1; return
  }
  ticket="${parsed%%$'\t'*}"
  is_hotfix="${parsed##*$'\t'}"

  uat_branch=$(trace_resolve_uat_branch "$ticket" "$is_hotfix" "$branch")
  [ -n "$uat_branch" ] || uat_branch="$branch"

  # Step 1: which branch to deploy. Dedupe: a hotfix's "uat branch" resolves
  # to the same string as its own branch (no parent to resolve), so don't
  # show two identical lines — just the one.
  branch_opts="ticket branch: $branch"
  [ "$uat_branch" != "$branch" ] && branch_opts="$branch_opts
uat branch: $uat_branch"

  branch_choice=$(printf '%s\n' "$branch_opts" | fzf \
    --layout=reverse --border=rounded --height=~6 \
    --header="Deploy $ticket — pick a branch (1/2 or ↑↓+Enter)" --prompt='branch ❯ ' \
    --pointer='▶' \
    --bind='1:pos(1)+accept,2:pos(2)+accept' \
    $mocha) || return
  [ -z "$branch_choice" ] && return
  branch_choice="${branch_choice#ticket branch: }"
  branch_choice="${branch_choice#uat branch: }"

  # Step 2: which job(s) to fire, all using $branch_choice as BRANCH. All 3
  # options are always visible (fzf lists every line by default, no
  # filtering applied) — the d/u/o binds are single-keystroke jumps straight
  # to accept (fzf's pos(N) action), not typed-search-then-Enter, so picking
  # one doesn't require arrowing to it first.
  job_choice=$(printf 'dev\nuat\none\n' | fzf \
    --layout=reverse --border=rounded --height=~6 \
    --header="Deploy $branch_choice — d/u/o to pick, or ↑↓+Enter" --prompt='job ❯ ' \
    --pointer='▶' \
    --bind='d:pos(1)+accept,u:pos(2)+accept,o:pos(3)+accept' \
    $mocha) || return
  [ -z "$job_choice" ] && return

  JENKINS_TOKEN=$(zsh -c 'source ~/.zshrc >/dev/null 2>&1; printf "%s" "$JENKINS_TOKEN"' 2>/dev/null)
  if [ -z "$JENKINS_TOKEN" ]; then
    echo "Error: JENKINS_TOKEN is not set."; sleep 1; return
  fi

  TRACE_NOTIFY_SUBTITLE="$ticket · $branch_choice"
  case "$job_choice" in
    dev)
      deploy_trigger_job mop_console_monorepo_dev BRANCH "$branch_choice" \
        && specs+=("DEV|mop_console_monorepo_dev|$branch_choice|one-dev deploy")
      ;;
    uat)
      deploy_trigger_job mop_console_monorepo_uat BRANCH "$branch_choice" \
        && specs+=("UAT|mop_console_monorepo_uat|$branch_choice|one-uat deploy")
      ;;
    one)
      deploy_trigger_job mop_console_monorepo_dev BRANCH "$branch_choice" \
        && specs+=("DEV|mop_console_monorepo_dev|$branch_choice|one-dev deploy")
      deploy_trigger_job mop_console_monorepo_uat BRANCH "$branch_choice" \
        && specs+=("UAT|mop_console_monorepo_uat|$branch_choice|one-uat deploy")
      ;;
    *)
      return
      ;;
  esac

  if [ "${#specs[@]}" -eq 0 ]; then
    echo "Deploy trigger failed."; sleep 1; return
  fi

  trace_run "${specs[@]}"
  if [ $? -eq 1 ]; then
    echo "No build showed up in Jenkins for the triggered job(s) — check Jenkins directly."
  fi

  echo ""
  echo "Press enter to return to the picker..."
  read -r _
}

# --- card list -----------------------------------------------------------
#
# Written to a file, not a variable: bash silently drops embedded NUL bytes
# from variables, which would collapse every card into one unselectable blob.
#
# Windows are only checked against the (relatively expensive) git resolution
# below when their pane path is under $WORKTREE_ROOT — a cheap string
# pre-filter ahead of the per-window git call. That one git call feeds both
# worktree-path fields: wt_path (MOP-only, serve_is_mop_path-gated) and
# build_wt_path (any mwt/wt worktree — build/trace doesn't care which repo).
build_list() {
  serve_compute_status
  CUR_TARGET=$(serve_current_target "$SERVE_WIN")
  : > "$list_file"

  tmux list-windows -a \
    -F "#{session_name}${TAB}#{window_id}${TAB}#{session_name} │ #{window_name}${TAB}#{@ticket_title}${TAB}#{pane_current_path}" \
    | while IFS="$TAB" read -r sess winid header title panepath; do
        case "$header" in
          *" │ $SERVE_WIN_NAME"|*" │ "*" $SERVE_WIN_NAME")
            continue  # hide the hidden serve window (suffix-matched like serve_find_window)
            ;;
        esac

        wt_path=""
        build_wt_path=""
        case "$panepath" in
          "$WORKTREE_ROOT"/*)
            top=$(git -C "$panepath" rev-parse --show-toplevel 2>/dev/null)
            if [ -n "$top" ]; then
              build_wt_path="$top"
              serve_is_mop_path "$top" && wt_path="$top"
            fi
            ;;
        esac

        record="${sess}${TAB}${winid}${TAB}${wt_path}${TAB}${build_wt_path}${TAB}${BOLD}${header}${RESET}"
        [ -n "$title" ] && record="${record}
  ${DIM}${title}${RESET}"

        if [ -n "$wt_path" ]; then
          if [ "$wt_path" = "$CUR_TARGET" ]; then
            status_line=$(printf '%s %s   http://localhost:%s' "$(serve_status_dot)" "$STATUS" "$SERVE_PORT")
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
          else
            record="${record}
  ${DIM}⚡ servable — ctrl-s to serve${RESET}"
          fi
        fi

        printf '%s\0' "$record" >> "$list_file"
      done
}

# --- main loop -------------------------------------------------------------
#
# enter/esc exit; ctrl-s/ctrl-r/ctrl-x/ctrl-v act and loop back into a
# refreshed picker, same idiom as tmux-serve-popup.sh used to.
while true; do
  build_list
  [ -s "$list_file" ] || exit 0

  HEADER=$(printf 'ctrl-s:serve  ctrl-r:restart  ctrl-x:stop  ctrl-g:trace build  ctrl-p:deploy\nctrl-v:view log  ctrl-l:reload ticket status')

  result=$(fzf \
    --read0 \
    --ansi \
    --gap=1 \
    --delimiter="$TAB" \
    --with-nth=5 \
    --layout=reverse \
    --border=rounded \
    --margin=0 \
    --header="$HEADER" \
    --header-first \
    --prompt='window ❯ ' \
    --pointer='▶' \
    --expect=ctrl-s,ctrl-r,ctrl-x,ctrl-v,ctrl-g,ctrl-p \
    --bind="$RELOAD_BIND" \
    --preview="$PREVIEW_CMD" \
    --preview-window=right:60%:wrap \
    $mocha < "$list_file") || exit 0

  [ -z "$result" ] && exit 0

  # --expect prepends the pressed key as its own line (empty for a plain
  # enter), ahead of the selected card — so the card's header line, which
  # would otherwise be line 1, is line 2.
  KEY=$(printf '%s\n' "$result" | sed -n '1p')
  first_line=$(printf '%s\n' "$result" | sed -n '2p')
  sess=$(printf '%s' "$first_line" | cut -d"$TAB" -f1)
  winid=$(printf '%s' "$first_line" | cut -d"$TAB" -f2)
  wt_path=$(printf '%s' "$first_line" | cut -d"$TAB" -f3)
  build_wt_path=$(printf '%s' "$first_line" | cut -d"$TAB" -f4)

  case "$KEY" in
    ctrl-s)
      if [ -z "$wt_path" ]; then
        echo "Not a MOP worktree window."; sleep 1; continue
      fi
      if [ "$wt_path" = "$CUR_TARGET" ]; then
        echo "Already serving this worktree."; sleep 1; continue
      fi
      serve_switch_to "$wt_path"
      continue
      ;;
    ctrl-r)
      if [ -z "$CUR_TARGET" ]; then echo "Nothing is being served."; sleep 1; continue; fi
      serve_switch_to "$CUR_TARGET"
      continue
      ;;
    ctrl-x)
      if [ -z "$CUR_TARGET" ]; then echo "Nothing is being served."; sleep 1; continue; fi
      serve_stop_current
      continue
      ;;
    ctrl-v)
      if [ -z "$CUR_TARGET" ]; then echo "Nothing is being served."; sleep 1; continue; fi
      tmux capture-pane -p -t "$SERVE_PANE" -S -500 | less -R +G
      continue
      ;;
    ctrl-g)
      if [ -z "$build_wt_path" ]; then
        echo "Not a worktree window."; sleep 1; continue
      fi
      trace_open_popup "$build_wt_path" || { sleep 1; continue; }
      exit 0
      ;;
    ctrl-p)
      if [ -z "$wt_path" ]; then
        echo "Not a MOP worktree window."; sleep 1; continue
      fi
      deploy_run "$wt_path"
      continue
      ;;
  esac

  [ -z "$winid" ] && continue
  tmux switch-client -t "$sess"
  tmux select-window -t "$winid"
  exit 0
done
