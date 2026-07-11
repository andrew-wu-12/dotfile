---
description: "Fetch a Jira ticket, classify it as feature or non-feature, and generate a full Traditional Chinese spec for feature tickets."
allowed-tools: Bash, Skill
---

# Ticket Spec Generator

**Ticket ID:** $ARGUMENTS

## Workflow

### Step 1 — Fetch
Use the `tool-ticket-get` skill to retrieve the ticket's title, description, issue type, and labels.

### Step 2 — Classify
Classify the ticket as one of:

- **feature**: new user-facing capability (view, form, workflow), API work for the above, new fields/columns/filters/actions
- **non-feature**: bug fix, regression fix, refactor/clean-up, spike, infrastructure-only
- **ambiguous**: conflicting or missing details

Log the classification decision and rationale before proceeding.

### Step 3 — Act

**If non-feature**, stop and respond:
> 此 ticket 不屬於功能性需求。請告知下一步，例如產出 bug spec 或忽略。

**If ambiguous**, ask the user for clarification.

**If feature**, generate the full spec below.

---

## Feature Spec Output

!`cat "$HOME/.claude/spec-output.md"`
