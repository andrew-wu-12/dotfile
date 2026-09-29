# Shared Jenkins job-trigger helper. Bash/zsh-compatible (`local`, no arrays/
# indirect-expansion) so it can be sourced directly by scripts in either shell.

DEPLOY_JENKINS_URL="https://jenkins.morrison.express"

# Fires buildWithParameters for job $1 with param $2=$3. Uses the caller's
# $JENKINS_TOKEN if set, else reads it from the credential store. Returns 0 on
# a 2xx response from Jenkins, nonzero otherwise.
deploy_trigger_job() {
  local job="$1" key="$2" value="$3" http_code

  : "${JENKINS_TOKEN:=$(~/bin/cred-read.sh jenkins.morrison.express)}"

  http_code=$(curl -s -o /dev/null -w '%{http_code}' \
    "$DEPLOY_JENKINS_URL/job/$job/buildWithParameters" \
    --user "$JENKINS_TOKEN" \
    --data "$key=$value")
  case "$http_code" in
    2??)
      echo "Triggered $job ($key=$value)"
      return 0
      ;;
    *)
      echo "Error: failed to trigger $job ($key=$value) — HTTP $http_code"
      return 1
      ;;
  esac
}
