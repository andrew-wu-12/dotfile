---
name: "tool-ticket-get"
description: "fetch Jira ticket metadata and content by ticket ID. Use this whenever a Jira ticket ID is provided and details about it are needed, such as title, description, issue type, or labels."
---

# Jira Ticket Retrieval Skill

## Purpose

Fetch a Jira ticket's metadata and content by ID using `~/bin/fetch-ticket.sh`,
which returns a structured JSON manifest (and downloads any image attachments).

## Prerequisites

- `JIRA_TOKEN` in the environment (`source ~/.zshrc`) and VPN. Do not hard-gate on
  `scutil` (it false-negatives); let the fetch surface real connectivity errors.

## Workflow

1. Take `ticket_id` as input (e.g. `MOP-27443`).
2. Run the fetch into a temp dir and read the manifest:
   ```bash
   OUT=$(mktemp -d)
   ~/bin/fetch-ticket.sh <ticket_id> "$OUT" > "$OUT/manifest.json"
   ```
3. Read `$OUT/manifest.json`. On success it contains:
   ```json
   {
     "ticket": "MOP-27443",
     "type": "Sub-task",
     "summary": "…",
     "priority": "…",
     "status": "…",
     "labels": ["…"],
     "parent": "MOP-25481",
     "description": "…(HTML-stripped plain text)…",
     "comments": [ { "author": "…", "created": "…", "body": "…" } ],
     "attachments": [ { "filename": "…", "mime": "image/png", "path": "…" } ]
   }
   ```
   Downloaded prototype/screenshot images are at each `attachments[].path` — Read
   them when the task needs the visual spec.
4. On failure the script exits non-zero with a clear message (bad ticket id / VPN /
   token) — surface that as actionable feedback rather than guessing.

## Example

```bash
OUT=$(mktemp -d); ~/bin/fetch-ticket.sh MOP-27443 "$OUT" > "$OUT/manifest.json"
```
