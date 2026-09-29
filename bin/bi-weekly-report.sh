#!/bin/zsh

SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/init-lib.sh"

dataset_date=$(date '+%Y-%m-%d')
p_dataset_date=$(date_days_ago 14)
echo "Start Date: ${p_dataset_date}"
echo "End Date: ${dataset_date}"
cd $MOP_MONOREPO_PATH
ON_GOING_PR=$(gh pr list --state open --assignee=@me --json title,body,url | sed 's/\r//g')
#echo $ON_GOING_PR
CLOSED_PR=$(gh pr list --state closed --search "created:$p_dataset_date..$dataset_date" --assignee=@me --json title,body,url | sed 's/\r//g')
#echo $CLOSED_PR
RESPONSE=$(jq -n --argjson on_going "$ON_GOING_PR" --argjson closed "$CLOSED_PR" '{ "on_going": $on_going, "closed": $closed }')
echo $RESPONSE | clip_copy
echo "Report copied to clipboard."
