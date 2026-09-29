# Forgejo backend for the build/trace engine (tmux-build-trace-lib.sh), dispatched by name when BUILD_BACKEND=forgejo.
# Requires BUILD_FORGEJO_URL + BUILD_FORGEJO_REPO (config) and $FORGEJO_TOKEN (set by forgejo_ensure_auth).
#
# Forgejo CI is the combined commit-status of a ref (the API aggregates every workflow job's status), so "$job"
# from a BUILD_JOBS spec is accepted but unused: one thing to trace per ref. Fine for a single workflow
# (pr-gate.yml); a second would need per-workflow filtering (actions/tasks API by workflow_id + head_sha).

forgejo_ensure_auth() {
  FORGEJO_TOKEN=$(cred_find "${BUILD_CRED_NAME:-git.tailcb6113.ts.net}")
  [ -n "$FORGEJO_TOKEN" ]
}

# Maps a commit-status state to trace_run's {result}: JSON null while unresolved (pending/unknown), else a
# final-result string. Only "SUCCESS" counts as a pass.
forgejo_map_state() {
  case "$1" in
    success) printf '"SUCCESS"' ;;
    failure) printf '"FAILURE"' ;;
    error)   printf '"ERROR"' ;;
    warning) printf '"FAILURE"' ;;
    *)       printf 'null' ;;
  esac
}

# Latest combined commit-status for ref $2 (branch or SHA) as JSON {number,url,result,timestamp,
# estimatedDuration,duration}, empty if the ref has no statuses. $url pins the resolved SHA so poll_build
# re-fetches the same commit even if the branch moves; $number is a short SHA (display only).
forgejo_find_build() {
  local ref="$2" ref_enc resp sha state result ts
  # Branch names with a "/" (test/foo, feature/MOP-1234, ...) must be
  # percent-encoded — Forgejo's router 404s on a literal "/" in this path
  # segment, silently mis-splitting it as extra path components.
  ref_enc=$(jq -rn --arg r "$ref" '$r|@uri')
  resp=$(curl -s -H "Authorization: token $FORGEJO_TOKEN" \
    "$BUILD_FORGEJO_URL/api/v1/repos/$BUILD_FORGEJO_REPO/commits/$ref_enc/status")
  sha=$(printf '%s' "$resp" | jq -r '.sha // empty' 2>/dev/null)
  [ -n "$sha" ] || return 1
  state=$(printf '%s' "$resp" | jq -r '.state // "pending"')
  result=$(forgejo_map_state "$state")
  ts=$(trace_get_time_ms)
  jq -nc \
    --arg number "${sha:0:7}" \
    --arg url "$BUILD_FORGEJO_URL/api/v1/repos/$BUILD_FORGEJO_REPO/commits/$sha/status" \
    --argjson result "$result" \
    --argjson ts "$ts" \
    '{number:$number, url:$url, result:$result, timestamp:$ts, estimatedDuration:null, duration:null}'
}

# estimatedDuration is always null (Forgejo gives no ETA), so trace_run shows elapsed time, not a percentage.
forgejo_poll_build() {
  local url="$1" resp state result building
  resp=$(curl -s -H "Authorization: token $FORGEJO_TOKEN" "$url")
  state=$(printf '%s' "$resp" | jq -r '.state // "pending"')
  result=$(forgejo_map_state "$state")
  [ "$state" = "pending" ] && building=true || building=false
  jq -nc --argjson result "$result" --argjson building "$building" \
    '{result:$result, building:$building, estimatedDuration:null}'
}
