# Backend-agnostic CI build-trace engine: discover, poll, render. Bash 3.2-clean.

TRACE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=tmux-build-config.sh
source "$TRACE_SCRIPT_DIR/tmux-build-config.sh"
# shellcheck source=init-lib.sh
source "$TRACE_SCRIPT_DIR/init-lib.sh"

trace_prepare() {
  local wt="$1" module auth_fn

  build_config_load "$wt"
  if [ -z "${BUILD_BACKEND:-}" ]; then
    echo "Error: no .tmux-build.conf found for $wt"
    return 1
  fi
  if [ -z "${BUILD_JOBS:-}" ]; then
    echo "Error: .tmux-build.conf for $wt sets no BUILD_JOBS"
    return 1
  fi

  module="$TRACE_SCRIPT_DIR/tmux-build-backend-${BUILD_BACKEND}.sh"
  if [ ! -f "$module" ]; then
    echo "Error: no backend module for BUILD_BACKEND=$BUILD_BACKEND ($module)"
    return 1
  fi
  # shellcheck source=/dev/null
  source "$module"

  auth_fn="${BUILD_BACKEND}_ensure_auth"
  if command -v "$auth_fn" >/dev/null 2>&1 && ! "$auth_fn"; then
    echo "Error: no credential found for ${BUILD_CRED_NAME:-$BUILD_BACKEND}"
    return 1
  fi
}

trace_job_spec() {
  local want="$1" branch="$2" key job role label
  while IFS='|' read -r key job role label; do
    if [ -n "$key" ] && [ "$job" = "$want" ]; then
      printf '%s|%s|%s|%s\n' "$key" "$job" "$branch" "$label"
      return 0
    fi
  done <<EOF
${BUILD_JOBS:-}
EOF
  printf '%s|%s|%s|%s\n' "$want" "$want" "$branch" "$want"
}

trace_vpn_connected() {
  scutil --nc list 2>/dev/null | grep -q "Connected"
}

# A missing backend function fails the job spec quietly instead of erroring.
trace_backend_find_build() {
  local fn="${BUILD_BACKEND}_find_build"
  command -v "$fn" >/dev/null 2>&1 || return 1
  "$fn" "$@"
}

trace_backend_poll_build() {
  local fn="${BUILD_BACKEND}_poll_build"
  command -v "$fn" >/dev/null 2>&1 || return 1
  "$fn" "$@"
}

trace_open_popup() {
  local wt="$1" branch cmd popup_cmd

  build_config_load "$wt"
  if [ -z "${BUILD_BACKEND:-}" ]; then
    echo "No .tmux-build.conf found for this worktree."
    return 1
  fi

  if [ "${BUILD_VPN_CHECK:-0}" = "1" ] && ! trace_vpn_connected; then
    echo "VPN required to trace builds."
    return 1
  fi

  branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)

  # Force exit status 0: run-shell -b would otherwise print a stray
  # "returned <code>" into the real terminal once the popup closes.
  cmd=$(printf '%q ' "$TRACE_SCRIPT_DIR/tmux-build-trace.sh" "$wt")
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

# Args: "KEY|JOB|BRANCH|LABEL" specs; optional $TRACE_NOTIFY_SUBTITLE. Returns 0 all succeeded, 2 any failed,
# 1 none found. Discovery retries ~16s since a just-triggered build sits in the CI queue before appearing.
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
        build=$(trace_backend_find_build "$job" "$branch")
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
      echo "⏳ Waiting for the triggered build to leave the queue... ($attempt/$max_attempts)"
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
        json=$(trace_backend_poll_build "$url")
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
          if [ -n "$est" ] && [ "$est" != "null" ] && [ "$est" -gt 0 ] 2>/dev/null; then
            percent=$((elapsed * 100 / est))
            eta=$((est - elapsed))
            [ "$eta" -lt 0 ] && eta=0
            bar=$(trace_draw_bar "$percent")
            line=$(printf '%-30s %s %3d%% (ETA: %s)' "$DISPLAY_NAME" "$bar" "$percent" "$(trace_format_duration "$eta")")
          else
            # No duration estimate: show elapsed instead of a fake percentage.
            line=$(printf '%-30s building... (Elapsed: %s)' "$DISPLAY_NAME" "$(trace_format_duration "$elapsed")")
          fi
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
  osascript -e 'on run argv' \
    -e 'display notification (item 1 of argv) with title (item 2 of argv) subtitle (item 3 of argv) sound name (item 4 of argv)' \
    -e 'end run' "$SUCCESS_COUNT Passed, $FAIL_COUNT Failed" "$TITLE" "${TRACE_NOTIFY_SUBTITLE:-}" "$SOUND" 2>/dev/null

  [ "$FAIL_COUNT" -eq 0 ] && return 0
  return 2
}
