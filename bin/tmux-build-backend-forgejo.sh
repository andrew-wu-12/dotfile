# Forgejo backend for the generic build/trace engine (tmux-build-trace-lib.sh).
# Dispatched by name (trace_backend_find_build/poll_build call
# "${BUILD_BACKEND}_find_build"/"_poll_build") when BUILD_BACKEND=forgejo.
# Requires BUILD_FORGEJO_URL + BUILD_FORGEJO_REPO (from config) and
# $FORGEJO_TOKEN (fetched by the caller via forgejo_ensure_auth, below).
#
# Unlike Jenkins (one job = one CI pipeline you trigger with a branch param),
# a Forgejo repo's CI is the combined commit-status of a ref — every workflow
# job posts its own status entry, and the repo's commit-status API already
# aggregates them into one state. So "$job" (the JOB field of a BUILD_JOBS
# spec) is accepted but unused here: there is exactly one thing to trace per
# ref, not one per workflow file. Fine for a repo with a single workflow
# (pr-gate.yml); would need real per-workflow filtering (the
# actions/tasks API, matched by workflow_id + head_sha) if a second
# workflow is ever added.

forgejo_ensure_auth() {
  FORGEJO_TOKEN=$(cred_find "${BUILD_CRED_NAME:-git.tailcb6113.ts.net}")
  [ -n "$FORGEJO_TOKEN" ]
}

# Maps a Forgejo commit-status "state" to the {result} vocabulary trace_run
# expects: JSON `null` while unresolved (pending/unknown, still building),
# else a quoted final-result string. "SUCCESS" is the only string trace_run
# treats as a pass; anything else counts as a fail.
forgejo_map_state() {
  case "$1" in
    success) printf '"SUCCESS"' ;;
    failure) printf '"FAILURE"' ;;
    error)   printf '"ERROR"' ;;
    warning) printf '"FAILURE"' ;;
    *)       printf 'null' ;;
  esac
}

# Latest combined commit-status for ref $2 (branch name or SHA), as compact
# JSON {number,url,result,timestamp,estimatedDuration,duration} (or empty if
# the ref has no statuses at all, e.g. a brand new branch with no CI run
# yet). $url pins the resolved SHA so poll_build re-fetches the same commit
# even if the branch moves. $number is a short SHA (display only, not a real
# build number — Forgejo has no single number for a combined status check).
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

# Polls the status URL from find_build for {result,building,estimatedDuration}.
# estimatedDuration is always null — Forgejo gives no ETA, so trace_run falls
# back to showing elapsed time instead of a fake percentage (same as its
# existing "e.g. GitHub Actions" fallback path).
forgejo_poll_build() {
  local url="$1" resp state result building
  resp=$(curl -s -H "Authorization: token $FORGEJO_TOKEN" "$url")
  state=$(printf '%s' "$resp" | jq -r '.state // "pending"')
  result=$(forgejo_map_state "$state")
  [ "$state" = "pending" ] && building=true || building=false
  jq -nc --argjson result "$result" --argjson building "$building" \
    '{result:$result, building:$building, estimatedDuration:null}'
}
