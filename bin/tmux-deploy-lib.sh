# Shared Jenkins job-trigger helper for deploy-one.sh and tmux-window-picker.sh's
# ctrl-p deploy action (deploy_run(), see that script). Written using only
# syntax both bash and zsh understand (`local`, no arrays/indirect-expansion/
# other bash-only or zsh-only extensions) since it's sourced directly by both
# a zsh script (deploy-one.sh) and a bash script (tmux-window-picker.sh) —
# unlike ticket-lib.sh (zsh-only, 1-based arrays), which is instead shelled
# into via `zsh -c` from bash contexts rather than sourced directly.

DEPLOY_JENKINS_URL="https://jenkins.morrison.express"

# Fires buildWithParameters for job $1 with BRANCH=$2. Requires $JENKINS_TOKEN
# set by the caller. Prints one status line and returns 0 on a 2xx response
# from Jenkins, nonzero otherwise — deploy-one.sh's original curl call never
# checked the response and always reported success regardless.
deploy_trigger_job() {
  local job="$1" branch="$2" http_code

  # Logged before the request fires so a bad job/branch/empty-token is
  # visible immediately instead of only showing up as an opaque HTTP code
  # (or, worse, a silent no-op if the job name is wrong and Jenkins 404s).
  # Token is masked to just its user-name half (before ':'), never the
  # secret half.
  echo "→ POST $DEPLOY_JENKINS_URL/job/$job/buildWithParameters BRANCH=$branch (user: ${JENKINS_TOKEN%%:*})"

  http_code=$(curl -s -o /dev/null -w '%{http_code}' \
    "$DEPLOY_JENKINS_URL/job/$job/buildWithParameters" \
    --user "$JENKINS_TOKEN" \
    --data BRANCH="$branch")
  case "$http_code" in
    2??)
      echo "Triggered $job ($branch)"
      return 0
      ;;
    *)
      echo "Error: failed to trigger $job ($branch) — HTTP $http_code"
      return 1
      ;;
  esac
}
