#!/bin/zsh

source ~/.zshrc

function get_from_json() {
    printf '%s\n' "$1" | jq -r "$2"
}

function get_ticket_content() {
    local TICKET_NUMBER="$1"
    local JIRA_TOKEN="$2"
    
    local RESPONSE=$(curl -s  \
        -u "$JIRA_TOKEN" \
        -X GET \
        -H "Content-Type: application/json" \
    "https://morrisonexpress.atlassian.net/rest/api/3/issue/${TICKET_NUMBER}/?fields=parent%2Cpriority%2Ccomponents%2Cissuetype%2Ccustomfield_10006%2Csummary&fieldsByKeys=false")
    
    local PARENT=$(get_from_json "$RESPONSE" '.fields.parent.key // "null"')
    if [[ "$PARENT" == "MOP-24745" ]]; then
        PARENT="null"
    fi
    printf '%s\n' "$RESPONSE" | jq --arg ticket "$TICKET_NUMBER" --arg parent "$PARENT" '{"ticket_number": $ticket, "parent": $parent, "issue_type": .fields.issuetype.name, "priority": .fields.priority.name, "summary": .fields.summary}'
}

# Dependencies check
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required."
    exit 1
fi
if ! command -v curl &> /dev/null; then
    echo "Error: curl is required."
    exit 1
fi
# opencode is likely an alias or function if it's not in path, but usually it is in path.
if ! command -v opencode &> /dev/null; then
    echo "Error: opencode CLI is required."
    exit 1
fi

TICKET_ID="$1"
if [[ -z "$TICKET_ID" ]]; then
    echo "Usage: $0 <TICKET-ID>"
    exit 1
fi

echo "Fetching Jira ticket $TICKET_ID..."

# 1. Fetch Basic Metadata using library.sh
# get_ticket_content returns JSON with: ticket_number, parent, issue_type, priority, summary
BASIC_DATA=$(get_ticket_content "$TICKET_ID" "$JIRA_TOKEN")

# Check if we got valid JSON
if ! echo "$BASIC_DATA" | jq -e . >/dev/null 2>&1; then
    echo "Error fetching ticket data. Please check TICKET_ID and JIRA_TOKEN."
    echo "Response: $BASIC_DATA"
    exit 1
fi

SUMMARY=$(echo "$BASIC_DATA" | jq -r '.summary')
PRIORITY=$(echo "$BASIC_DATA" | jq -r '.priority')
ISSUE_TYPE=$(echo "$BASIC_DATA" | jq -r '.issue_type')
PARENT=$(echo "$BASIC_DATA" | jq -r '.parent')

# 2. Fetch Description & Comments (Rendered)
# We need a separate call because library.sh limits fields
JIRA_URL="https://morrisonexpress.atlassian.net" # extracted from library.sh
API_URL="$JIRA_URL/rest/api/3/issue/$TICKET_ID?expand=renderedFields"

# Use a temp file to handle large responses safely
TEMP_JSON=$(mktemp)
curl -s -u "$JIRA_TOKEN" \
-X GET \
-H "Content-Type: application/json" \
"$API_URL" > "$TEMP_JSON"

# Check if response is valid JSON
if ! jq -e . "$TEMP_JSON" >/dev/null 2>&1; then
    echo "Error fetching detailed ticket data. Continuing with basic data..."
    DESCRIPTION="Description fetch failed."
    COMMENTS="Comments fetch failed."
else
    DESCRIPTION=$(jq -r '.renderedFields.description // .fields.description // "No description provided."' "$TEMP_JSON")
    COMMENTS=$(jq -r '.renderedFields.comment.comments[]?.body // empty' "$TEMP_JSON")
fi

rm -f "$TEMP_JSON"

echo "Ticket Found: $SUMMARY ($PRIORITY)"
echo "Generating feature description..."

# 3. Construct Prompt
PROMPT="You are a Lead Technical Analyst specializing in Web Development. Review the following Jira ticket and generate a detailed feature specification.

CRITICAL INSTRUCTION: Do not summarize away technical details. You must include all specific field names, API parameters, validation rules, error codes, and logic flows exactly as they appear in the description or comments.

Format:
- **Title:** [Issue Key] - [Summary]
- **Overview:** Summary of the web feature.
- **User Stories (Step-by-step):** List the user journey steps or stories in a logical sequence (e.g., 1. User navigates to..., 2. User clicks..., 3. System displays...). Use 'As a [User], I want [Goal], so that [Benefit]' format where appropriate but ensure the flow is clear.
- **Acceptance Criteria:** Bulleted list of conditions for success (UI/UX, functional, non-functional). Include all negative test cases, edge cases, and validation errors mentioned in the source text.
- **Technical Considerations:** Frontend components, API endpoints, database schema changes, security notes.

Ticket Details:
Key: $TICKET_ID
Type: $ISSUE_TYPE
Summary: $SUMMARY
Priority: $PRIORITY
Parent: $PARENT

Description:
$DESCRIPTION

Comments:
$COMMENTS
"

# 4. Call opencode & Copy to Clipboard
# Use standard output for display and pipe to pbcopy
opencode run "$PROMPT" --model github-copilot/gpt-4o | tee >(pbcopy)

echo ""
echo "✅ Output copied to clipboard."
