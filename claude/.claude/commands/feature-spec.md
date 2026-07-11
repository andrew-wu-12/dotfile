---
description: "Write a full feature specification in Traditional Chinese directly from a Jira ticket ID. Use when you already know the ticket is a feature ticket."
allowed-tools: Bash, Skill
---

# Feature Spec Writer

**Ticket ID:** $ARGUMENTS

## Workflow

1. Use the `tool-ticket-get` skill to fetch the ticket's title, description, issue type, and labels.
2. Generate the full specification below using only concrete details from the ticket.

---

## Spec Output

!`cat "$HOME/.claude/spec-output.md"`
