# Jenkins backend for the generic build/trace engine (tmux-build-trace-lib.sh).
# Dispatched by name (trace_backend_find_build/poll_build call
# "${BUILD_BACKEND}_find_build"/"_poll_build") when BUILD_BACKEND=jenkins.
# Requires BUILD_JENKINS_URL (from config) and $JENKINS_TOKEN (fetched by the
# caller via cred_find "$BUILD_CRED_NAME").

# Latest build in Jenkins job $1 matching BRANCH param $2, as compact JSON
# {number,url,result,timestamp,estimatedDuration,duration} (or empty).
jenkins_find_build() {
  local job="$1" branch="$2"
  curl -s -g --user "$JENKINS_TOKEN" \
    "$BUILD_JENKINS_URL/job/$job/api/json?tree=builds[number,url,result,timestamp,estimatedDuration,duration,actions[parameters[name,value]]]{0,50}" \
    | jq -c --arg BRANCH "$branch" '
        first(.builds[]? | select(.actions[]? | .parameters[]? | select(.value == $BRANCH)) | {number, url, result, timestamp, estimatedDuration, duration})
      ' 2>/dev/null
}

# Polls a build's URL $1 for {result,building,estimatedDuration} as compact JSON.
jenkins_poll_build() {
  local url="$1"
  curl -s --user "$JENKINS_TOKEN" "${url}api/json?tree=result,building,estimatedDuration" 2>/dev/null \
    | jq -c '{result, building, estimatedDuration}' 2>/dev/null
}
