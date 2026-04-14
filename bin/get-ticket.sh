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
    ATTACHMENTS_JSON="[]"
else
    DESCRIPTION=$(jq -r '.renderedFields.description // .fields.description // "No description provided."' "$TEMP_JSON")
    COMMENTS=$(jq -r '.renderedFields.comment.comments[]?.body // empty' "$TEMP_JSON")
    # Fetch Attachments
    ATTACHMENTS_JSON=$(jq -c '.fields.attachment // []' "$TEMP_JSON")
fi

rm -f "$TEMP_JSON"

# Create a temporary directory for attachments
ATTACH_DIR=$(mktemp -d)
trap 'rm -rf "$ATTACH_DIR"' EXIT

# Download Image Attachments
echo "Checking for image attachments..."
FILE_ARGS=()

if [[ "$ATTACHMENTS_JSON" != "[]" && "$ATTACHMENTS_JSON" != "null" ]]; then
    # Parse JSON array and iterate
    # We select only images to avoid downloading large binaries or irrelevant files
    echo "$ATTACHMENTS_JSON" | jq -r '.[] | select(.mimeType | startswith("image/")) | "\(.content) \(.filename)"' | while read -r url filename; do
        # Sanitize filename
        SAFE_FILENAME=$(echo "$filename" | sed 's/[^a-zA-Z0-9._-]/_/g')
        filepath="$ATTACH_DIR/$SAFE_FILENAME"
        
        echo "Downloading image: $filename..."
        curl -s -u "$JIRA_TOKEN" -L -o "$filepath" "$url"
        
        if [[ -f "$filepath" ]]; then
            FILE_ARGS+=("--file" "$filepath")
        fi
    done
else
    echo "No image attachments found."
fi

echo "Ticket Found: $SUMMARY ($PRIORITY)"
echo "Generating feature description..."

# 3. Construct Input Data for Agent
echo "Ticket Details:
Key: $TICKET_ID
Type: $ISSUE_TYPE
Summary: $SUMMARY
Priority: $PRIORITY
Parent: $PARENT

Description:
$DESCRIPTION

Comments:
$COMMENTS"