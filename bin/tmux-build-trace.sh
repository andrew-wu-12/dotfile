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
# The 4 jobs are fixed, so per-job state lives in plainly-named variables
# (FEAT_*/DEV_*/EPIC_*/UAT_*) rather than an associative array, reached via
# bash indirect expansion (${!name}, available since bash 2.0) — this script
# has its own #!/bin/bash shebang and is invoked directly, so it doesn't need
# tmux-build-trace-lib.sh's bash-3.2 constraint (which exists only because
# that lib is sourced from tmux-window-picker.sh).
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

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

find_build_in_job() {  # $1 job  $2 branch
  local job="$1" branch="$2"
  curl -s -g --user "$JENKINS_TOKEN" \
    "$TRACE_JENKINS_URL/job/$job/api/json?tree=builds[number,url,result,timestamp,estimatedDuration,duration,actions[parameters[name,value]]]{0,50}" \
    | jq -c --arg BRANCH "$branch" '
        first(.builds[]? | select(.actions[]? | .parameters[]? | select(.value == $BRANCH)) | {number, url, result, timestamp, estimatedDuration, duration})
      ' 2>/dev/null
}

discover() {  # $1=key  $2=job  $3=branch
  local key="$1" job="$2" branch="$3" build
  build=$(find_build_in_job "$job" "$branch")
  if [ -n "$build" ] && [ "$build" != "null" ]; then
    printf '%s\n' "$build" > "$TMP_DIR/$key.json"
  fi
}

discover FEAT mop_console_monorepo_feature "$BRANCH" &
discover DEV  mop_console_monorepo_dev "$BRANCH" &
discover EPIC mop_console_monorepo_epic_or_hotfix "$UAT_BRANCH" &
discover UAT  mop_console_monorepo_uat "$UAT_BRANCH" &
wait

LABEL_FEAT="feature build"
LABEL_DEV="one-dev deploy"
LABEL_EPIC="epic/hotfix build"
LABEL_UAT="one-uat deploy"

TRACKED_KEYS=""
for pfx in FEAT DEV EPIC UAT; do
  file="$TMP_DIR/$pfx.json"
  [ -f "$file" ] || continue
  TRACKED_KEYS="$TRACKED_KEYS $pfx"
  eval "${pfx}_NUMBER=\$(jq -r '.number' '$file')"
  eval "${pfx}_URL=\$(jq -r '.url' '$file')"
  eval "${pfx}_RESULT=\$(jq -r '.result' '$file')"
  eval "${pfx}_TS=\$(jq -r '.timestamp' '$file')"
  eval "${pfx}_EST=\$(jq -r '.estimatedDuration' '$file')"
  eval "${pfx}_DUR=\$(jq -r '.duration' '$file')"
done
TRACKED_KEYS="${TRACKED_KEYS# }"

if [ -z "$TRACKED_KEYS" ]; then
  echo "❌ No recent builds found for $TICKET ($BRANCH / $UAT_BRANCH)"
  exec "${SHELL:-zsh}"
fi

NUM_TRACKED=0
for _ in $TRACKED_KEYS; do NUM_TRACKED=$((NUM_TRACKED + 1)); done
echo "⏳ Tracing $NUM_TRACKED build(s)..."
printf '\033[?25l'
trap 'printf "\033[?25h"' EXIT

get_time_ms() {
  perl -MTime::HiRes -e 'printf("%.0f\n",Time::HiRes::time()*1000)'
}

format_duration() {
  local ms=$1 seconds minutes rem
  [ "$ms" -lt 0 ] 2>/dev/null && ms=0
  seconds=$((ms / 1000))
  minutes=$((seconds / 60))
  rem=$((seconds % 60))
  echo "${minutes}m ${rem}s"
}

draw_bar() {
  local percent=$1 width=20 completed remaining i
  [ "$percent" -gt 100 ] && percent=100
  [ "$percent" -lt 0 ] && percent=0
  completed=$((width * percent / 100))
  remaining=$((width - completed))
  printf "["
  for ((i = 0; i < completed; i++)); do printf "#"; done
  for ((i = 0; i < remaining; i++)); do printf "."; done
  printf "]"
}

FIRST_RUN=true

while true; do
  ALL_DONE=true
  CURRENT_TIME=$(get_time_ms)

  [ "$FIRST_RUN" = "false" ] && printf "\033[%dA" "$NUM_TRACKED"
  FIRST_RUN=false

  for pfx in $TRACKED_KEYS; do
    label_var="LABEL_${pfx}"; number_var="${pfx}_NUMBER"; url_var="${pfx}_URL"
    result_var="${pfx}_RESULT"; ts_var="${pfx}_TS"; est_var="${pfx}_EST"; dur_var="${pfx}_DUR"

    label="${!label_var}"; number="${!number_var}"; url="${!url_var}"
    result="${!result_var}"; ts="${!ts_var}"; est="${!est_var}"

    DISPLAY_NAME="$label #$number"
    printf '\033[K'

    if [ "$result" = "null" ] || [ "$result" = "BUILDING" ]; then
      ALL_DONE=false
      json=$(curl -s --user "$JENKINS_TOKEN" "${url}api/json?tree=result,building,estimatedDuration" 2>/dev/null)
      building=$(printf '%s' "$json" | jq -r '.building' 2>/dev/null)
      new_result=$(printf '%s' "$json" | jq -r '.result' 2>/dev/null)
      new_est=$(printf '%s' "$json" | jq -r '.estimatedDuration' 2>/dev/null)
      if [ -n "$new_est" ] && [ "$new_est" != "null" ] && [ "$new_est" -gt 0 ] 2>/dev/null; then
        eval "$est_var=\$new_est"
        est=$new_est
      fi

      if [ "$building" = "false" ]; then
        eval "$result_var=\$new_result"
        duration=$((CURRENT_TIME - ts))
        eval "${dur_var}=\$duration"
        printf '%-30s %s (Duration: %s)\n' "$DISPLAY_NAME" "$new_result" "$(format_duration "$duration")"
      else
        elapsed=$((CURRENT_TIME - ts))
        if [ "$est" -gt 0 ] 2>/dev/null; then
          percent=$((elapsed * 100 / est))
          eta=$((est - elapsed))
        else
          percent=0; eta=0
        fi
        [ "$eta" -lt 0 ] && eta=0
        bar=$(draw_bar "$percent")
        printf '%-30s %s %3d%% (ETA: %s)\n' "$DISPLAY_NAME" "$bar" "$percent" "$(format_duration "$eta")"
      fi
    else
      dur_val="${!dur_var}"
      printf '%-30s %s (Duration: %s)\n' "$DISPLAY_NAME" "$result" "$(format_duration "${dur_val:-0}")"
    fi
  done

  $ALL_DONE && break
  sleep 2
done

printf '\033[?25h'
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0
for pfx in $TRACKED_KEYS; do
  result_var="${pfx}_RESULT"
  if [ "${!result_var}" = "SUCCESS" ]; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done

echo "🏁 All builds finished."

if [ "$FAIL_COUNT" -eq 0 ]; then
  TITLE="Builds Succeeded"; SOUND="Glass"
else
  TITLE="Builds Failed"; SOUND="Basso"
fi

osascript -e "display notification \"$SUCCESS_COUNT Passed, $FAIL_COUNT Failed\" with title \"$TITLE\" subtitle \"$TICKET · $BRANCH\" sound name \"$SOUND\"" 2>/dev/null

echo ""
echo "(this window stays open — close it manually when you're done)"
exec "${SHELL:-zsh}"
