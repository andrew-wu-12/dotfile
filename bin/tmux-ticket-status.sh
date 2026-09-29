#!/bin/zsh
# Ticket dev-status report for mwt worktrees: spec path, a per-ticket block (PR, Jira, preview, Jenkins) for the
# feature/hotfix ticket and, when one exists, its epic, then a Deploy block (deploy plan, one-uat/one-dev Jenkins
# status). Print-and-exit: tmux-window-picker.sh's fzf --preview re-invokes it for each highlighted card.
#
# Usage:
#   tmux-ticket-status.sh [DIR]           print the report (DIR default $PWD)
#   tmux-ticket-status.sh --reload [DIR]  bust the cache for DIR, print nothing
# The ticket comes from the branch checked out in DIR (feature/<ticket> or hotfix/<ticket>), not the worktree
# path. Links are plain URLs for WezTerm's cmd-click.
#
# Caching: everything except "spec created" is one JSON blob in "${ROOT}.status-cache.json" (sibling of the
# worktree, like worktree-ticket.sh's ".title" file; worktree-done.sh cleans it up). Fetched links and statuses
# don't change retroactively, so the report is one unit: fetched live once, then served from cache until an
# explicit ctrl-l reload in the picker (which calls --reload). No TTL: staleness is manual, by design.
# "spec created" is a local stat() and the field most likely to flip mid-session, so it's always recomputed.
# ~/.zshrc and ticket-lib.sh (tokens, JIRA helpers) are sourced lazily after the cache check, so a hit is just
# a git rev-parse plus a jq read.
#
# PR status: Draft/Open/Closed/Approved/Merged/Not opened/Error (Error = the gh lookup failed); the symbol is
# derived at render time (pr_symbol_state). Jira status keeps its own state+value pair (jira_status_check):
# its names are open-ended text, and done means matching $UAT_GATE_STATUS.
#
# Three states: done / pending / error. Pending = not happened yet (no PR, no build, wrong Jira status), a
# normal mid-flight state; error = the check itself failed (bad token, network, non-2xx), so a broken
# integration doesn't read as normal progress. Hotfix/Production-Support tickets have no uat/<parent>, so their
# reports have no Epic block; if the epic lookup fails for a feature ticket the Epic block still renders with
# error rows, since "no epic" and "couldn't check" are different facts.

emulate -L zsh
set -u
zmodload zsh/datetime

SCRIPT_DIR="${0:A:h}"

RELOAD=false
if [[ "${1:-}" == "--reload" ]]; then
    RELOAD=true
    shift
fi

TARGET_DIR="${1:-$PWD}"

JENKINS_URL="https://jenkins.morrison.express"
JIRA_API="https://morrisonexpress.atlassian.net/rest/api/3/issue"
WIKI="https://morrisonexpress.atlassian.net/wiki"
JIRA_BROWSE="https://morrisonexpress.atlassian.net/browse"
UAT_GATE_STATUS="UAT VERIFIED"
SPECS_DIR="$HOME/personal/office-note/Specs"

GREEN=$'\033[38;2;166;227;161m'
YELLOW=$'\033[38;2;249;226;175m'
RED=$'\033[38;2;243;139;168m'
GREY=$'\033[38;2;127;132;156m'
BOLD=$'\033[1m'
DIM="$GREY"
RESET=$'\033[0m'

fail() {
    echo "$1"
    exit "${2:-1}"
}

symbol() {
    case "$1" in
        done)    printf '%s✓%s' "$GREEN" "$RESET" ;;
        pending) printf '%s○%s' "$GREY" "$RESET" ;;
        failed)  printf '%s✗%s' "$RED" "$RESET" ;;
        error)   printf '%s⚠%s' "$YELLOW" "$RESET" ;;
        na)      printf '%s–%s' "$GREY" "$RESET" ;;
    esac
}

# ticket_number + env -> per-env preview URL (same template as ticket-lib.sh's pr_get_content); pure string
# work, recomputed on every render.
mop_preview_url() {
    local ticket_number="$1" env="$2"
    local parts=("${(@s/-/)ticket_number}")
    printf 'https://mop-%s.%s.morrison.express/' "${parts[2]}" "$env"
}

# jenkins.morrison.express is only reachable over VPN (same check as deploy-one.sh).
vpn_connected() {
    scutil --nc list 2>/dev/null | grep -q "Connected"
}

row() {  # $1 state  $2 label  $3 detail (optional)
    local detail="${3:-}"
    printf '  %s  %s' "$(symbol "$1")" "$2"
    [[ -n "$detail" ]] && printf '  %s%s%s' "$DIM" "$detail" "$RESET"
    printf '\n'
}

# One row of an info block: $1 state, $2 label, $3 status text (optional), $4 url (optional). "na" prints just the label.
info_row() {
    local state="$1" label="$2" statustext="${3:-}" url="${4:-}"
    if [[ "$state" == "na" ]]; then
        printf '  %s  %-5s' "$(symbol na)" "$label"
        [[ -n "$statustext" ]] && printf ' %s%s%s' "$DIM" "$statustext" "$RESET"
        printf '\n'
        return
    fi
    printf '  %s  %-5s' "$(symbol "$state")" "$label"
    [[ -n "$statustext" ]] && printf ' %s%-14s%s' "$DIM" "$statustext" "$RESET"
    [[ -n "$url" ]] && printf ' %s' "$url"
    printf '\n'
}

# Approved and Merged are the only "done" PR states; Closed-without-merge is pending (nothing to do), not an
# error, since the lookup didn't fail.
pr_symbol_state() {
    case "$1" in
        Approved|Merged) echo done ;;
        Error)            echo error ;;
        *)                echo pending ;;
    esac
}

# gh pr view for branch $1 -> "STATUS<TAB>URL". MERGED beats draft/review state; draft beats review decision
# (a draft can show a stale reviewDecision from before it was converted back to draft).
pr_check() {
    local branch="$1" out rc state isdraft decision url text
    out=$(gh pr view "$branch" --json url,reviewDecision,state,isDraft 2>&1)
    rc=$?
    if [[ $rc -ne 0 ]]; then
        if [[ "$out" == *"no pull requests found"* ]]; then
            printf 'Not opened\t\n'
        else
            printf 'Error\t\n'
        fi
        return
    fi
    state=$(printf '%s' "$out" | jq -r '.state')
    isdraft=$(printf '%s' "$out" | jq -r '.isDraft')
    decision=$(printf '%s' "$out" | jq -r '.reviewDecision')
    url=$(printf '%s' "$out" | jq -r '.url')
    if [[ "$state" == "MERGED" ]]; then
        text="Merged"
    elif [[ "$isdraft" == "true" ]]; then
        text="Draft"
    elif [[ "$decision" == "APPROVED" ]]; then
        text="Approved"
    elif [[ "$state" == "CLOSED" ]]; then
        text="Closed"
    else
        text="Open"
    fi
    printf '%s\t%s\n' "$text" "$url"
}

# Jira ticket's status field vs $UAT_GATE_STATUS -> "STATE<TAB>STATUS_NAME".
jira_status_check() {
    local ticket="$1" resp jira_status
    resp=$(curl -s -u "$JIRA_TOKEN" -H "Content-Type: application/json" \
        "$JIRA_API/$ticket?fields=status")
    jira_status=$(printf '%s' "$resp" | jq -r '.fields.status.name // empty' 2>/dev/null)
    if [[ -z "$jira_status" ]]; then
        printf 'error\tError\n'
    elif [[ "${jira_status:u}" == "${UAT_GATE_STATUS:u}" ]]; then
        printf 'done\t%s\n' "$jira_status"
    else
        printf 'pending\t%s\n' "$jira_status"
    fi
}

# Latest build in Jenkins job $1 with BRANCH param $2 -> "STATE<TAB>DETAIL" (result word + trigger time HH:MM);
# like trace-build.sh's find_build_in_job, single-shot. FAILURE is its own "failed" state (red); still building,
# no build yet, and other results (ABORTED/UNSTABLE/...) stay pending; only a broken API call is error.
jenkins_deploy_check() {
    local job="$1" branch="$2" resp build result ts_ms ts_sec time_str label
    resp=$(curl -s -g --user "$JENKINS_TOKEN" \
        "$JENKINS_URL/job/$job/api/json?tree=builds[number,url,result,timestamp,actions[parameters[name,value]]]{0,50}")
    if [[ -z "$resp" ]]; then
        printf 'error\tError\n'
        return
    fi
    build=$(printf '%s' "$resp" | jq -r --arg BRANCH "$branch" '
        first(.builds[]? | select(.actions[]? | .parameters[]? | select(.value == $BRANCH)) | {number, result, timestamp})
    ' 2>/dev/null)
    if [[ -z "$build" || "$build" == "null" ]]; then
        printf 'pending\tNot run yet\n'
        return
    fi
    result=$(printf '%s' "$build" | jq -r '.result')
    ts_ms=$(printf '%s' "$build" | jq -r '.timestamp')
    ts_sec=$(( ts_ms / 1000 ))
    time_str=""
    strftime -s time_str '%H:%M' "$ts_sec"
    case "$result" in
        SUCCESS)  printf 'done\tSuccess · %s\n' "$time_str" ;;
        FAILURE)  printf 'failed\tFailed · %s\n' "$time_str" ;;
        null)     printf 'pending\tBuilding · %s\n' "$time_str" ;;
        ABORTED)  printf 'pending\tAborted · %s\n' "$time_str" ;;
        UNSTABLE) printf 'pending\tUnstable · %s\n' "$time_str" ;;
        *)        printf 'pending\t%s · %s\n' "$result" "$time_str" ;;
    esac
}

# CQL title search for the epic's deploy-plan page, same convention as
# create-deploy-plan/scripts/find_deploy_parent.sh -> "STATE<TAB>URL".
confluence_check() {
    local epic_key="$1" epic_summary="$2" title cql resp count webui
    title="$epic_key $epic_summary"
    cql=$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(f"space=MOP and title=\"{sys.argv[1]}\""))' "$title")
    resp=$(curl -s -u "$JIRA_TOKEN" "$WIKI/rest/api/content/search?cql=$cql&limit=5")
    if [[ -z "$resp" ]]; then
        printf 'error\t\n'
        return
    fi
    count=$(printf '%s' "$resp" | jq -r '.results | length' 2>/dev/null)
    if [[ -z "$count" ]]; then
        printf 'error\t\n'
        return
    fi
    if [[ "$count" -eq 0 ]]; then
        printf 'pending\t\n'
        return
    fi
    webui=$(printf '%s' "$resp" | jq -r '.results[0]._links.webui // ""')
    printf 'done\t%s%s\n' "$WIKI" "$webui"
}

cd "$TARGET_DIR" 2>/dev/null || fail "No such directory: $TARGET_DIR"

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
[[ -z "$BRANCH" ]] && fail "Not inside a git repository."

ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
CACHE_FILE="${ROOT}.status-cache.json"

# --reload only busts the cache file (no ticket lookup or sourcing); the picker's ctrl-l chains a preview
# refresh that re-invokes this script and repopulates it.
if $RELOAD; then
    rm -f "$CACHE_FILE"
    exit 0
fi

case "$BRANCH" in
    feature/MOP-*) TICKET_NUMBER="${BRANCH#feature/}"; IS_HOTFIX=false ;;
    hotfix/MOP-*)  TICKET_NUMBER="${BRANCH#hotfix/}";  IS_HOTFIX=true ;;
    *)
        fail "Not on a MOP feature/hotfix branch (current: $BRANCH)."
        ;;
esac

SPEC_PATH="$SPECS_DIR/$TICKET_NUMBER.md"
if [[ -e "$SPEC_PATH" ]]; then
    SPEC_STATE=done
else
    SPEC_STATE=pending
fi

CACHE_HIT=false
if [[ -f "$CACHE_FILE" ]]; then
    # \x1f, not a tab: a tab in IFS is whitespace, so read squeezes runs of it and drops empty fields, shifting
    # every later field (several, e.g. uat_deploy_detail, are legitimately empty and not last). \x1f isn't
    # whitespace, so empty fields stay positional.
    CACHE_ROW=$(jq -r '[.fetched_at, .ticket_summary, .has_epic, .epic_error, .parent_ticket_number,
        .feature_pr_status, .feature_pr_url, .epic_pr_status, .epic_pr_url,
        .jira_status_state, .jira_status_value, .epic_jira_status_state, .epic_jira_status_value,
        .dev_deploy_state, .dev_deploy_detail, .uat_deploy_state, .uat_deploy_detail,
        .confluence_state, .confluence_url]
        | map(tostring) | join("")' "$CACHE_FILE" 2>/dev/null)
    if [[ -n "$CACHE_ROW" ]]; then
        IFS=$'\x1f' read -r FETCHED_AT TICKET_SUMMARY HAS_EPIC EPIC_ERROR PARENT_TICKET_NUMBER \
            FEATURE_PR_STATUS FEATURE_PR_URL EPIC_PR_STATUS EPIC_PR_URL \
            JIRA_STATUS_STATE JIRA_STATUS_VALUE EPIC_JIRA_STATUS_STATE EPIC_JIRA_STATUS_VALUE \
            DEV_DEPLOY_STATE DEV_DEPLOY_DETAIL UAT_DEPLOY_STATE UAT_DEPLOY_DETAIL \
            CONFLUENCE_STATE CONFLUENCE_URL <<< "$CACHE_ROW"
        CACHE_HIT=true
    fi
fi

if ! $CACHE_HIT; then
    source "$SCRIPT_DIR/ticket-lib.sh"
    source ~/.zshrc

    TICKET_DATA=$(get_ticket_content "$TICKET_NUMBER")
    TICKET_SUMMARY=$(get_from_json "$TICKET_DATA" ".summary" 2>/dev/null)
    JIRA_OK=true
    [[ -z "$TICKET_SUMMARY" || "$TICKET_SUMMARY" == "null" ]] && JIRA_OK=false

    HAS_EPIC=false
    EPIC_ERROR=false
    PARENT_TICKET_NUMBER=""
    if ! $IS_HOTFIX; then
        if $JIRA_OK; then
            HAS_EPIC=true
            PARENT_DATA=$(get_ticket_parent "$TICKET_DATA")
            PARENT_TICKET_NUMBER=$(get_from_json "$PARENT_DATA" ".ticket_number")
            PARENT_SUMMARY=$(get_from_json "$PARENT_DATA" ".summary")
            UAT_BRANCH="uat/$PARENT_TICKET_NUMBER"
        else
            EPIC_ERROR=true
        fi
    fi

    IFS=$'\t' read -r FEATURE_PR_STATUS FEATURE_PR_URL <<< "$(pr_check "$BRANCH")"

    if $HAS_EPIC; then
        IFS=$'\t' read -r EPIC_PR_STATUS EPIC_PR_URL <<< "$(pr_check "$UAT_BRANCH")"
    else
        EPIC_PR_STATUS=""; EPIC_PR_URL=""
    fi

    IFS=$'\t' read -r JIRA_STATUS_STATE JIRA_STATUS_VALUE <<< "$(jira_status_check "$TICKET_NUMBER")"

    if $HAS_EPIC; then
        IFS=$'\t' read -r EPIC_JIRA_STATUS_STATE EPIC_JIRA_STATUS_VALUE <<< "$(jira_status_check "$PARENT_TICKET_NUMBER")"
    else
        EPIC_JIRA_STATUS_STATE=""; EPIC_JIRA_STATUS_VALUE=""
    fi

    # jenkins.morrison.express is VPN-only: skip both live calls when the VPN is down instead of failing slowly
    # one by one. The "no epic to check" case is a structural error independent of VPN.
    if vpn_connected; then
        IFS=$'\t' read -r DEV_DEPLOY_STATE DEV_DEPLOY_DETAIL <<< "$(jenkins_deploy_check mop_console_monorepo_dev "$BRANCH")"
        if $IS_HOTFIX; then
            IFS=$'\t' read -r UAT_DEPLOY_STATE UAT_DEPLOY_DETAIL <<< "$(jenkins_deploy_check mop_console_monorepo_uat "$BRANCH")"
        elif $HAS_EPIC; then
            IFS=$'\t' read -r UAT_DEPLOY_STATE UAT_DEPLOY_DETAIL <<< "$(jenkins_deploy_check mop_console_monorepo_uat "$UAT_BRANCH")"
        else
            UAT_DEPLOY_STATE=error; UAT_DEPLOY_DETAIL="Error"
        fi
    else
        DEV_DEPLOY_STATE=pending; DEV_DEPLOY_DETAIL="VPN required"
        if $IS_HOTFIX || $HAS_EPIC; then
            UAT_DEPLOY_STATE=pending; UAT_DEPLOY_DETAIL="VPN required"
        else
            UAT_DEPLOY_STATE=error; UAT_DEPLOY_DETAIL="Error"
        fi
    fi

    if $HAS_EPIC; then
        IFS=$'\t' read -r CONFLUENCE_STATE CONFLUENCE_URL <<< "$(confluence_check "$PARENT_TICKET_NUMBER" "$PARENT_SUMMARY")"
    elif $EPIC_ERROR; then
        CONFLUENCE_STATE=error; CONFLUENCE_URL=""
    else
        CONFLUENCE_STATE=na; CONFLUENCE_URL=""
    fi

    FETCHED_AT=$EPOCHSECONDS

    jq -n \
        --argjson fetched_at "$FETCHED_AT" \
        --arg ticket_summary "${TICKET_SUMMARY:-}" \
        --argjson has_epic "$HAS_EPIC" \
        --argjson epic_error "$EPIC_ERROR" \
        --arg parent_ticket_number "${PARENT_TICKET_NUMBER:-}" \
        --arg feature_pr_status "$FEATURE_PR_STATUS" \
        --arg feature_pr_url "$FEATURE_PR_URL" \
        --arg epic_pr_status "$EPIC_PR_STATUS" \
        --arg epic_pr_url "$EPIC_PR_URL" \
        --arg jira_status_state "$JIRA_STATUS_STATE" \
        --arg jira_status_value "$JIRA_STATUS_VALUE" \
        --arg epic_jira_status_state "$EPIC_JIRA_STATUS_STATE" \
        --arg epic_jira_status_value "$EPIC_JIRA_STATUS_VALUE" \
        --arg dev_deploy_state "$DEV_DEPLOY_STATE" \
        --arg dev_deploy_detail "$DEV_DEPLOY_DETAIL" \
        --arg uat_deploy_state "$UAT_DEPLOY_STATE" \
        --arg uat_deploy_detail "$UAT_DEPLOY_DETAIL" \
        --arg confluence_state "$CONFLUENCE_STATE" \
        --arg confluence_url "$CONFLUENCE_URL" \
        '{fetched_at: $fetched_at, ticket_summary: $ticket_summary, has_epic: $has_epic,
          epic_error: $epic_error, parent_ticket_number: $parent_ticket_number,
          feature_pr_status: $feature_pr_status, feature_pr_url: $feature_pr_url,
          epic_pr_status: $epic_pr_status, epic_pr_url: $epic_pr_url,
          jira_status_state: $jira_status_state, jira_status_value: $jira_status_value,
          epic_jira_status_state: $epic_jira_status_state, epic_jira_status_value: $epic_jira_status_value,
          dev_deploy_state: $dev_deploy_state, dev_deploy_detail: $dev_deploy_detail,
          uat_deploy_state: $uat_deploy_state, uat_deploy_detail: $uat_deploy_detail,
          confluence_state: $confluence_state, confluence_url: $confluence_url}' \
        > "$CACHE_FILE"
fi

UPDATED_TIME=""
strftime -s UPDATED_TIME '%H:%M:%S' "$FETCHED_AT"

printf '%s%s (%s)%s\n' "$BOLD" "$TICKET_NUMBER" "$BRANCH" "$RESET"
[[ "$TICKET_SUMMARY" != "null" && -n "$TICKET_SUMMARY" ]] && printf '%s%s%s\n' "$DIM" "$TICKET_SUMMARY" "$RESET"
printf '%sUpdated %s · ctrl-l to reload%s\n' "$DIM" "$UPDATED_TIME" "$RESET"
echo

row "$SPEC_STATE" "spec created" "$SPEC_PATH"
echo

if $IS_HOTFIX; then
    printf '%sHotfix (%s)%s\n' "$BOLD" "$TICKET_NUMBER" "$RESET"
else
    printf '%sFeature (%s)%s\n' "$BOLD" "$TICKET_NUMBER" "$RESET"
fi
if $IS_HOTFIX; then FEATURE_ENV="uat"; else FEATURE_ENV="dev"; fi
info_row "$(pr_symbol_state "$FEATURE_PR_STATUS")" "PR" "$FEATURE_PR_STATUS" "$FEATURE_PR_URL"
info_row "$JIRA_STATUS_STATE" "Jira" "$JIRA_STATUS_VALUE" "$JIRA_BROWSE/$TICKET_NUMBER"
info_row done "Preview" "" "$(mop_preview_url "$TICKET_NUMBER" "$FEATURE_ENV")"
# A hotfix owns both dev+uat builds via the Deploy section but has one ticket block, so show uat here (the
# meaningful gate).
if $IS_HOTFIX; then
    info_row "$UAT_DEPLOY_STATE" "Jenkins" "$UAT_DEPLOY_DETAIL"
else
    info_row "$DEV_DEPLOY_STATE" "Jenkins" "$DEV_DEPLOY_DETAIL"
fi

if ! $IS_HOTFIX; then
    echo
    if $HAS_EPIC; then
        printf '%sEpic (%s)%s\n' "$BOLD" "$PARENT_TICKET_NUMBER" "$RESET"
        info_row "$(pr_symbol_state "$EPIC_PR_STATUS")" "PR" "$EPIC_PR_STATUS" "$EPIC_PR_URL"
        info_row "$EPIC_JIRA_STATUS_STATE" "Jira" "$EPIC_JIRA_STATUS_VALUE" "$JIRA_BROWSE/$PARENT_TICKET_NUMBER"
        info_row done "Preview" "" "$(mop_preview_url "$PARENT_TICKET_NUMBER" uat)"
        info_row "$UAT_DEPLOY_STATE" "Jenkins" "$UAT_DEPLOY_DETAIL"
    elif $EPIC_ERROR; then
        printf '%sEpic%s\n' "$BOLD" "$RESET"
        info_row error "PR" "Error"
        info_row error "Jira" "Error"
        info_row error "Preview" "Error"
        info_row error "Jenkins" "Error"
    fi
fi

echo
printf '%sDeploy%s\n' "$BOLD" "$RESET"
if [[ "$CONFLUENCE_STATE" == "na" ]]; then
    info_row na "Deploy plan" "$($IS_HOTFIX && echo '(n/a for hotfix)')"
elif [[ "$CONFLUENCE_STATE" == "error" ]]; then
    info_row error "Deploy plan" "Error"
else
    info_row "$CONFLUENCE_STATE" "Deploy plan" "" "$CONFLUENCE_URL"
fi
info_row "$UAT_DEPLOY_STATE" "one-uat" "$UAT_DEPLOY_DETAIL"
info_row "$DEV_DEPLOY_STATE" "one-dev" "$DEV_DEPLOY_DETAIL"
