---
name: "tool-ticket-get"
description: "a tool to get JIRA Ticket"
---

# Jira Ticket Retrieval Skill

## Purpose:

Fetches original Jira ticket information metadata and content using the `~/bin/get-ticket.sh` shell script.

## Features:

1. Accepts a `ticket_id` as input parameter.
2. Executes the script `~/bin/get-ticket.sh <ticket_id>` to retrieve ticket details (title, description, labels, etc.).
3. Processes the output and validates its structure and fields, ensuring metadata consistency.
4. Handles failure scenarios:
   - Invalid ticket ID.
   - Script execution errors.

## Workflow:

1. Takes `ticket_id` as input.
2. Runs `~/bin/get-ticket.sh <ticket_id>`.
3. Validates the retrieved output:
   - **Success:**
     - Return processed JSON containing ticket metadata (e.g., `title`, `description`, `labels`).
   - **Failure:**
     - Capture error message and return actionable feedback for the agent (e.g., "Invalid ticket ID.").
4. Outputs structured fields for use by other agent tasks:
   ```json
   {
     "ticket_id": "PROJ-123",
     "title": "Implement user login",
     "description": "The user login system should integrate with OAuth.",
     "labels": ["frontend", "api", "auth"]
   }
   ```

## Example Command:

```bash
# Example run for ticket PROJ-123
~/bin/get-ticket.sh PROJ-123
```
