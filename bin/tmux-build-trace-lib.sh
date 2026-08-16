# Shared Jenkins build-trace helpers: discover, poll, and render progress
# for one or more builds until they finish. Bash 3.2-clean.

TRACE_JENKINS_URL="https://jenkins.morrison.express"
TRACE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# True if VPN is connected (jenkins.morrison.express is only reachable over VPN).
trace_vpn_connected() {
  scutil --nc list 2>/dev/null | grep -q "Connected"
}

# Ticket number + hotfix flag from branch name $1, tab-separated
# ("MOP-1234<TAB>false"). Nonzero exit and no output if $1 isn't a
# feature/hotfix branch.
trace_parse_branch() {
  case "$1" in
    feature/MOP-*) printf '%s\tfalse\n' "${1#feature/}" ;;
    hotfix/MOP-*)  printf '%s\ttrue\n'  "${1#hotfix/}"  ;;
    *) return 1 ;;
  esac
}

# uat/<parent> for ticket $1 (feature, via JIRA parent lookup), or branch $3
# itself when $2 (is_hotfix) is true. Prints the branch name, or empty +
# nonzero exit if the parent lookup fails.
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

# Opens the build-trace popup for worktree path $1. Prints an error and
# returns nonzero if VPN is down or the branch isn't feature/hotfix.
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

  # Force exit status 0: run-shell -b would otherwise print a stray
  # "returned <code>" into the real terminal once the popup closes.
  cmd=$(printf '%q ' "$TRACE_SCRIPT_DIR/tmux-build-trace.sh" "$wt" "$branch" "$ticket" "$is_hotfix")
  popup_cmd=$(printf 'sleep 0.3 && tmux display-popup -E -w 90%% -h 80%% -d %q %s || true' "$wt" "$cmd")
  tmux run-shell -b "$popup_cmd"
}

trace_get_time_ms() {
  perl -MTime::HiRes -e 'printf("%.0f\n",Time::HiRes::time()*1000)'
}

trace_format_duration() {
  local ms=$1 seconds minutes rem
  [ "$ms" -lt 0 ] 2>/dev/null && ms=0
  seconds=$((ms / 1000))
  minutes=$((seconds / 60))
  rem=$((seconds % 60))
  echo "${minutes}m ${rem}s"
}

trace_draw_bar() {
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

# Latest build in Jenkins job $1 matching BRANCH param $2, as compact JSON (or
# empty). Requires $JENKINS_TOKEN set by the caller.
trace_find_build_in_job() {
  local job="$1" branch="$2"
  curl -s -g --user "$JENKINS_TOKEN" \
    "$TRACE_JENKINS_URL/job/$job/api/json?tree=builds[number,url,result,timestamp,estimatedDuration,duration,actions[parameters[name,value]]]{0,50}" \
    | jq -c --arg BRANCH "$branch" '
        first(.builds[]? | select(.actions[]? | .parameters[]? | select(.value == $BRANCH)) | {number, url, result, timestamp, estimatedDuration, duration})
      ' 2>/dev/null
}

# Discovers, polls until done, and renders one or more Jenkins jobs in place;
# prints a summary and fires a completion osascript notification. Does not
# exec into a shell.
#
# Args: one or more "KEY|JOB|BRANCH|LABEL" specs. Requires $JENKINS_TOKEN;
# $TRACE_NOTIFY_SUBTITLE (optional) sets the notification subtitle.
#
# Returns 1 if no spec ever found a matching build (retries discovery for
# ~16s, since a just-triggered build sits in Jenkins's queue briefly before
# appearing); 0 if every tracked build succeeded; 2 if at least one didn't.
trace_run() {
  local TMP_DIR spec key job branch label build rest
  local TRACKED_KEYS="" file attempt max_attempts=8

  for spec in "$@"; do
    key="${spec%%|*}"; rest="${spec#*|}"
    rest="${rest#*|}"; label="${rest#*|}"
    eval "LABEL_${key}=\$label"
  done

  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    TMP_DIR=$(mktemp -d)

    for spec in "$@"; do
      key="${spec%%|*}"; rest="${spec#*|}"
      job="${rest%%|*}"; rest="${rest#*|}"
      branch="${rest%%|*}"
      (
        build=$(trace_find_build_in_job "$job" "$branch")
        if [ -n "$build" ] && [ "$build" != "null" ]; then
          printf '%s\n' "$build" > "$TMP_DIR/$key.json"
        fi
      ) &
    done
    wait

    TRACKED_KEYS=""
    for spec in "$@"; do
      key="${spec%%|*}"
      file="$TMP_DIR/$key.json"
      [ -f "$file" ] || continue
      TRACKED_KEYS="$TRACKED_KEYS $key"
      eval "${key}_NUMBER=\$(jq -r '.number' '$file')"
      eval "${key}_URL=\$(jq -r '.url' '$file')"
      eval "${key}_RESULT=\$(jq -r '.result' '$file')"
      eval "${key}_TS=\$(jq -r '.timestamp' '$file')"
      eval "${key}_EST=\$(jq -r '.estimatedDuration' '$file')"
      eval "${key}_DUR=\$(jq -r '.duration' '$file')"
    done
    TRACKED_KEYS="${TRACKED_KEYS# }"
    rm -rf "$TMP_DIR"

    [ -n "$TRACKED_KEYS" ] && break
    if [ "$attempt" -lt "$max_attempts" ]; then
      echo "⏳ Waiting for the triggered build to leave Jenkins's queue... ($attempt/$max_attempts)"
      sleep 2
    fi
  done

  [ -n "$TRACKED_KEYS" ] || return 1

  local NUM_TRACKED=0
  for key in $TRACKED_KEYS; do NUM_TRACKED=$((NUM_TRACKED + 1)); done
  printf '\033[?25l'
  trap 'printf "\033[?25h"' RETURN

  # Redraw from the top (\033[H) and erase below (\033[J) each tick, rather
  # than cursor-up-by-N, so a scrolled/resized pane can't desync the frame.
  local ALL_DONE CURRENT_TIME cols line header
  local label_var number_var url_var result_var ts_var est_var dur_var
  local number url result ts est DISPLAY_NAME json building new_result new_est duration elapsed percent eta bar dur_val
  while true; do
    ALL_DONE=true
    CURRENT_TIME=$(trace_get_time_ms)

    cols=$(tput cols 2>/dev/null)
    [ -n "$cols" ] && [ "$cols" -gt 1 ] 2>/dev/null || cols=80
    cols=$((cols - 1))

    printf '\033[H'
    header="⏳ Tracing $NUM_TRACKED build(s)..."
    printf '%.*s\033[K\n\033[K\n' "$cols" "$header"

    for key in $TRACKED_KEYS; do
      label_var="LABEL_${key}"; number_var="${key}_NUMBER"; url_var="${key}_URL"
      result_var="${key}_RESULT"; ts_var="${key}_TS"; est_var="${key}_EST"; dur_var="${key}_DUR"

      number="${!number_var}"; url="${!url_var}"
      result="${!result_var}"; ts="${!ts_var}"; est="${!est_var}"

      DISPLAY_NAME="${!label_var} #$number"

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
          line=$(printf '%-30s %s (Duration: %s)' "$DISPLAY_NAME" "$new_result" "$(trace_format_duration "$duration")")
        else
          elapsed=$((CURRENT_TIME - ts))
          if [ "$est" -gt 0 ] 2>/dev/null; then
            percent=$((elapsed * 100 / est))
            eta=$((est - elapsed))
          else
            percent=0; eta=0
          fi
          [ "$eta" -lt 0 ] && eta=0
          bar=$(trace_draw_bar "$percent")
          line=$(printf '%-30s %s %3d%% (ETA: %s)' "$DISPLAY_NAME" "$bar" "$percent" "$(trace_format_duration "$eta")")
        fi
      else
        dur_val="${!dur_var}"
        line=$(printf '%-30s %s (Duration: %s)' "$DISPLAY_NAME" "$result" "$(trace_format_duration "${dur_val:-0}")")
      fi

      printf '%.*s\033[K\n' "$cols" "$line"
    done

    printf '\033[J'

    $ALL_DONE && break
    sleep 2
  done
  printf '\033[?25h'
  echo ""

  local SUCCESS_COUNT=0 FAIL_COUNT=0
  for key in $TRACKED_KEYS; do
    result_var="${key}_RESULT"
    if [ "${!result_var}" = "SUCCESS" ]; then
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  done

  echo "🏁 All builds finished."

  local TITLE SOUND
  if [ "$FAIL_COUNT" -eq 0 ]; then
    TITLE="Builds Succeeded"; SOUND="Glass"
  else
    TITLE="Builds Failed"; SOUND="Basso"
  fi
  osascript -e "display notification \"$SUCCESS_COUNT Passed, $FAIL_COUNT Failed\" with title \"$TITLE\" subtitle \"${TRACE_NOTIFY_SUBTITLE:-}\" sound name \"$SOUND\"" 2>/dev/null

  [ "$FAIL_COUNT" -eq 0 ] && return 0
  return 2
}
