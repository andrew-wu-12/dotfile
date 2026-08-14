#!/bin/zsh
# Ticket dev-status report for mwt worktrees: spec path, then a per-ticket
# info block (PR link+status, Jira link+status, preview link, Jenkins
# status) for the feature/hotfix ticket and, when one exists, its epic —
# finally a Deploy block (deploy plan link, one-uat/one-dev Jenkins status
# with last-trigger time, same numbers as the per-ticket Jenkins rows, just
# side-by-side). Print-and-exit, no interactivity — called by
# tmux-window-picker.sh's fzf --preview for the highlighted card's worktree
# path, which re-invokes on every highlighted row and expects a plain
# print-and-exit command.
#
# Usage:
#   tmux-ticket-status.sh [DIR]           print the report (DIR default $PWD)
#   tmux-ticket-status.sh --reload [DIR]  bust the cache for DIR, print nothing
#
# Ticket is resolved from the branch checked out in DIR (feature/<ticket> or
# hotfix/<ticket>), not the worktree path itself.  Links are plain URLs for
# WezTerm's own cmd-click.
#
# Caching: the whole report (everything below except "spec created") is
# cached as one JSON blob in a sibling file next to the worktree,
# "${ROOT}.status-cache.json" — same convention as worktree-ticket.sh's
# ".title" file, and cleaned up by worktree-done.sh the same way. PR/Jira/
# Jenkins/Confluence links and statuses never change retroactively once
# fetched (aside from lifecycle progress you drive yourself), so it's safe
# to treat the whole report as one unit: it is fetched live once, then
# served from cache until you explicitly reload with ctrl-l in the picker
# (tmux-window-picker.sh's ctrl-l binding calls this script with --reload
# then refreshes the preview). There is no automatic TTL — staleness is
# entirely manual, by design.
#
# "spec created" is excluded from the cache: it's a local stat() with no
# network cost, and the one field you're likely to flip mid-session while
# looking at this exact card, so it's always recomputed live.
#
# On a cache hit no network calls happen at all, so ~/.zshrc and
# ticket-lib.sh (needed only for tokens and JIRA helpers) are sourced lazily,
# after the cache check — a hit is just a git rev-parse plus a jq read.
#
# PR status is one of Draft/Open/Closed/Approved/Merged/Not opened/Error
# (Not opened = no PR exists yet, Error = the gh lookup itself failed). The
# ✓/○/⚠ symbol is derived from that text at render time (see
# pr_symbol_state): Approved/Merged → done, Error → error, everything else
# → pending. Jira status keeps its own state+value pair (jira_status_check)
# since Jira status names are open-ended text, not a fixed enum — done means
# the value matches $UAT_GATE_STATUS, not any particular string.
#
# Three-state checklist: done / pending / error. "Pending" covers anything
# that hasn't happened yet (no PR opened, no matching build, wrong Jira
# status) — expected mid-flight states, not failures. "Error" is reserved for
# the check itself failing (bad token, network, non-2xx) so a broken
# integration doesn't read the same as normal in-progress work. There's no
# uat/<parent> branch for hotfix/Production-Support tickets, so hotfix
# reports have no Epic block at all; if the epic *lookup* fails (Jira
# unreachable) for a feature ticket, the Epic block still renders with
# ⚠ Error rows rather than being silently hidden, since "no epic" and
# "couldn't check" are different facts.

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

# ticket_number (MOP-1234) + env (dev/uat) -> the ticket's per-env preview
# URL, same template as ticket-lib.sh's pr_get_content(). Pure string work,
# no network/cache needed — recomputed live every render, cache hit or not.
mop_preview_url() {
    local ticket_number="$1" env="$2"
    local parts=("${(@s/-/)ticket_number}")
    printf 'https://mop-%s.%s.morrison.express/' "${parts[2]}" "$env"
}

# macOS VPN profile state, same check used by deploy-one.sh/deploy-i18n.sh/
# checkout-ticket.sh — jenkins.morrison.express is only reachable over VPN.
vpn_connected() {
    scutil --nc list 2>/dev/null | grep -q "Connected"
}

row() {  # $1 state  $2 label  $3 detail (optional)
    local detail="${3:-}"
    printf '  %s  %s' "$(symbol "$1")" "$2"
    [[ -n "$detail" ]] && printf '  %s%s%s' "$DIM" "$detail" "$RESET"
    printf '\n'
}

# One row of a ticket/deploy info block. $1 state  $2 label  $3 status text
# (optional — PR/Jira status word, or a Jenkins build detail)  $4 url
# (optional). "na" state prints just the label, like the old link_row.
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

# done/pending/error for a PR status TEXT (Draft/Open/Closed/Approved/
# Merged/Not opened/Error). Approved and Merged are the only "done" states —
# Closed-without-merge is treated as pending (nothing more to do right now)
# rather than as an error, since it's not the lookup that failed.
pr_symbol_state() {
    case "$1" in
        Approved|Merged) echo done ;;
        Error)            echo error ;;
        *)                echo pending ;;
    esac
}

# gh pr view for $1 (branch name) -> prints "STATUS<TAB>URL", STATUS one of
# Draft/Open/Closed/Approved/Merged/Not opened/Error. MERGED beats
# draft/review state; draft beats review decision (a draft can still show a
# stale reviewDecision from before it was converted back to draft).
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

# Latest build in Jenkins job $1 matching BRANCH param $2 -> "STATE<TAB>DETAIL",
# DETAIL being the result word plus the build's trigger time (HH:MM). Mirrors
# trace-build.sh's find_build_in_job, single-shot (no polling). FAILURE gets
# its own "failed" state (red ✗) since it's meaningfully different from
# "still building" or "no build found yet" — those, and any other result
# (ABORTED/UNSTABLE/etc.), stay "pending". Only a broken API call is "error".
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

# --reload never needs to know the ticket, or even source anything — it just
# busts the cache file; the picker's ctrl-l binding chains a refresh-preview
# right after, which re-invokes this script normally and repopulates it.
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

# 1. Spec created — always live, see the caching note in the file header.
SPEC_PATH="$SPECS_DIR/$TICKET_NUMBER.md"
if [[ -e "$SPEC_PATH" ]]; then
    SPEC_STATE=done
else
    SPEC_STATE=pending
fi

CACHE_HIT=false
if [[ -f "$CACHE_FILE" ]]; then
    # \x1f (unit separator), not a tab: IFS=<tab> is still an "IFS whitespace"
    # character to read/word-splitting, which squeezes runs of it and drops
    # empty fields — fatal here since several fields (e.g. uat_deploy_detail)
    # are legitimately empty and NOT last in the list, so a squeeze would
    # shift every field after it by one. \x1f isn't whitespace, so empty
    # fields are preserved positionally, same reasoning as IFS=: for
    # /etc/passwd-style parsing.
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

    # 2. Feature/hotfix PR status (the ticket's own branch, whichever prefix)
    IFS=$'\t' read -r FEATURE_PR_STATUS FEATURE_PR_URL <<< "$(pr_check "$BRANCH")"

    # 3. Epic PR status (uat/<parent> branch)
    if $HAS_EPIC; then
        IFS=$'\t' read -r EPIC_PR_STATUS EPIC_PR_URL <<< "$(pr_check "$UAT_BRANCH")"
    else
        EPIC_PR_STATUS=""; EPIC_PR_URL=""
    fi

    # 4. Jira status verified (feature/hotfix ticket itself)
    IFS=$'\t' read -r JIRA_STATUS_STATE JIRA_STATUS_VALUE <<< "$(jira_status_check "$TICKET_NUMBER")"

    # 5. Jira status verified (epic ticket, same check against the parent)
    if $HAS_EPIC; then
        IFS=$'\t' read -r EPIC_JIRA_STATUS_STATE EPIC_JIRA_STATUS_VALUE <<< "$(jira_status_check "$PARENT_TICKET_NUMBER")"
    else
        EPIC_JIRA_STATUS_STATE=""; EPIC_JIRA_STATUS_VALUE=""
    fi

    # 6/7. one-dev/one-uat Jenkins deployed. jenkins.morrison.express is
    # VPN-only, so skip both live calls when the VPN is down instead of
    # letting them fail slowly one by one; the "no epic to check" case below
    # is a structural na/error independent of VPN, not a network failure.
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

    # Confluence deploy plan (epic only)
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
# Hotfix owns both dev+uat Jenkins builds via the Deploy section below, but
# only has one ticket block, so show uat here (dev alone would understate
# how far it's actually deployed for a hotfix, uat is the meaningful gate).
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
