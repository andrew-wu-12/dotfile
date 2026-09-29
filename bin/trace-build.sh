#!/bin/zsh

# Required parameters
# @raycast.schemaVersion 1
# @raycast.title Jenkins: Trace Build
# @raycast.packageName Jenkins Tools
# @raycast.mode fullOutput
#
# Optional parameters
# @raycast.icon 🔍
# @raycast.argument1 {"type": "text", "placeholder": "Branch Name" }

source ~/.zshrc

emulate -L zsh

BRANCH_NAME=$1

if [[ -z "$BRANCH_NAME" ]]; then
    echo "Error: Branch name is required."
    exit 1
fi

if [[ -z "$JENKINS_TOKEN" ]]; then
    echo "Error: JENKINS_TOKEN is not set."
    exit 1
fi

JENKINS_URL="https://jenkins.morrison.express"
JOBS=("mop_console_bulild_by_feature" "mop_console_bulild_by_epic_or_hotfix" "mop_console_monorepo_feature" "mop_console_monorepo_epic_or_hotfix")

echo "🔍 Searching for recent builds for branch: $BRANCH_NAME..."

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

get_time_ms() {
    perl -MTime::HiRes -e 'printf("%.0f\n",Time::HiRes::time()*1000)'
}

format_duration() {
    local ms=$1
    if [[ $ms -lt 0 ]]; then ms=0; fi
    local seconds=$((ms / 1000))
    local minutes=$((seconds / 60))
    local rem_seconds=$((seconds % 60))
    echo "${minutes}m ${rem_seconds}s"
}

draw_bar() {
    local percent=$1
    local width=20
    if [[ $percent -gt 100 ]]; then percent=100; fi
    if [[ $percent -lt 0 ]]; then percent=0; fi
    
    local completed=$(( width * percent / 100 ))
    local remaining=$(( width - completed ))
    
    printf "["
    for ((i=0; i<completed; i++)); do printf "#"; done
    for ((i=0; i<remaining; i++)); do printf "."; done
    printf "]"
}

find_build_in_job() {
    local JOB_NAME=$1
    local API_URL="$JENKINS_URL/job/$JOB_NAME/api/json?tree=builds[number,url,result,timestamp,estimatedDuration,duration,actions[parameters[name,value]]]{0,50}"

    # -g: disable curl globbing, which interferes with [] and {} in the URL
    local RESPONSE=$(curl -s -g "$API_URL" --user "$JENKINS_TOKEN")

    echo "$RESPONSE" | jq -r --arg BRANCH "$BRANCH_NAME" '
       first(
           .builds[] | 
           select(
               .actions[]? | .parameters[]? | select(.value == $BRANCH)
           ) | 
           {number, url, result, timestamp, estimatedDuration, duration}
       )
   '
}

for JOB in "${JOBS[@]}"; do
    (
        RESULT_JSON=$(find_build_in_job "$JOB")
        if [[ -n "$RESULT_JSON" && "$RESULT_JSON" != "null" ]]; then
            echo "$RESULT_JSON" > "$TEMP_DIR/$JOB.json"
        fi
    ) &
done
wait

typeset -A JOB_URLS JOB_NUMS JOB_STATUS JOB_TIMESTAMPS JOB_ESTIMATED JOB_DURATIONS
TRACKED_JOBS=()

for JOB in "${JOBS[@]}"; do
    if [[ -f "$TEMP_DIR/$JOB.json" ]]; then
        RESULT_JSON=$(cat "$TEMP_DIR/$JOB.json")
        BUILD_NUM=$(echo "$RESULT_JSON" | jq -r '.number')
        BUILD_URL=$(echo "$RESULT_JSON" | jq -r '.url')
        BUILD_RESULT=$(echo "$RESULT_JSON" | jq -r '.result')
        TIMESTAMP=$(echo "$RESULT_JSON" | jq -r '.timestamp')
        ESTIMATED=$(echo "$RESULT_JSON" | jq -r '.estimatedDuration')
        DURATION=$(echo "$RESULT_JSON" | jq -r '.duration')
        
        JOB_URLS[$JOB]=$BUILD_URL
        JOB_NUMS[$JOB]=$BUILD_NUM
        JOB_TIMESTAMPS[$JOB]=$TIMESTAMP
        JOB_ESTIMATED[$JOB]=$ESTIMATED
        
        if [[ "$BUILD_RESULT" == "null" ]]; then
             JOB_STATUS[$JOB]="BUILDING"
        else
             JOB_STATUS[$JOB]=$BUILD_RESULT
             JOB_DURATIONS[$JOB]=$DURATION
        fi
        
        TRACKED_JOBS+=("$JOB")
    fi
done

if [[ ${#TRACKED_JOBS[@]} -eq 0 ]]; then
    echo "❌ No recent builds found for branch: $BRANCH_NAME"
    exit 1
fi

echo "⏳ Tracing ${#TRACKED_JOBS[@]} builds..."
printf "\033[?25l"
trap "printf '\033[?25h'; rm -rf $TEMP_DIR" EXIT

FIRST_RUN=true

while true; do
    ALL_DONE=true
    CURRENT_TIME=$(get_time_ms)
    
    if [[ "$FIRST_RUN" == "false" ]]; then
        printf "\033[${#TRACKED_JOBS[@]}A"
    fi
    FIRST_RUN=false
    
    for JOB in "${TRACKED_JOBS[@]}"; do
        STATUS=${JOB_STATUS[$JOB]}
        START_TIME=${JOB_TIMESTAMPS[$JOB]}
        EST_DURATION=${JOB_ESTIMATED[$JOB]}
        
        DISPLAY_NAME="$JOB #${JOB_NUMS[$JOB]}"
        if [[ ${#DISPLAY_NAME} -gt 35 ]]; then
            DISPLAY_NAME="${DISPLAY_NAME:0:32}..."
        fi
        
        printf "\033[K"
        
        if [[ "$STATUS" == "BUILDING" ]]; then
            ALL_DONE=false
            
            BUILD_URL=${JOB_URLS[$JOB]}
            BUILD_API_URL="${BUILD_URL}api/json?tree=result,building,estimatedDuration"
            BUILD_STATUS_JSON=$(curl -s --user "$JENKINS_TOKEN" "$BUILD_API_URL")
            
            IS_BUILDING=$(echo "$BUILD_STATUS_JSON" | jq -r '.building')
            RESULT=$(echo "$BUILD_STATUS_JSON" | jq -r '.result')
            NEW_EST=$(echo "$BUILD_STATUS_JSON" | jq -r '.estimatedDuration')
            if [[ "$NEW_EST" != "null" && "$NEW_EST" -gt 0 ]]; then
                EST_DURATION=$NEW_EST
                JOB_ESTIMATED[$JOB]=$NEW_EST
            fi
            
            if [[ "$IS_BUILDING" == "false" ]]; then
                JOB_STATUS[$JOB]=$RESULT
                DURATION=$((CURRENT_TIME - START_TIME))
                JOB_DURATIONS[$JOB]=$DURATION
                STATUS=$RESULT
                printf "%-35s %s (Duration: %s)\n" "$DISPLAY_NAME" "$STATUS" "$(format_duration $DURATION)"
            else
                ELAPSED=$((CURRENT_TIME - START_TIME))
                if [[ $EST_DURATION -gt 0 ]]; then
                    PERCENT=$((ELAPSED * 100 / EST_DURATION))
                    ETA=$((EST_DURATION - ELAPSED))
                else
                    PERCENT=0
                    ETA=0
                fi
                
                if [[ $ETA -lt 0 ]]; then ETA=0; fi
                
                BAR=$(draw_bar $PERCENT)
                ETA_STR=$(format_duration $ETA)
                
                printf "%-35s %s %3d%% (ETA: %s)\n" "$DISPLAY_NAME" "$BAR" "$PERCENT" "$ETA_STR"
            fi
        else
            DURATION=${JOB_DURATIONS[$JOB]}
            printf "%-35s %s (Duration: %s)\n" "$DISPLAY_NAME" "$STATUS" "$(format_duration $DURATION)"
        fi
    done
    
    if $ALL_DONE; then
        break
    fi
    
    sleep 2
done

printf "\033[?25h" # Show cursor
echo "" # Newline

SUMMARY=""
FAIL_COUNT=0
SUCCESS_COUNT=0

for JOB in "${TRACKED_JOBS[@]}"; do
    STATUS=${JOB_STATUS[$JOB]}
    SUMMARY+="$JOB: $STATUS | "
    if [[ "$STATUS" == "SUCCESS" ]]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

echo "🏁 All builds finished."

if [[ $FAIL_COUNT -eq 0 ]]; then
    TITLE="Builds Succeeded"
    SOUND="Glass"
else
    TITLE="Builds Failed"
    SOUND="Basso"
fi

osascript -e 'on run argv' \
  -e 'display notification (item 1 of argv) with title (item 2 of argv) subtitle (item 3 of argv) sound name (item 4 of argv)' \
  -e 'end run' "$SUCCESS_COUNT Passed, $FAIL_COUNT Failed" "$TITLE" "Branch: $BRANCH_NAME" "$SOUND"
