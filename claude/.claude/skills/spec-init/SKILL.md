---
name: spec-init
description: >-
  Create a persistent, codebase-grounded spec note for a MOP Jira ticket or a
  homelab Forgejo issue, plus a private Open Questions list: fetch the ticket,
  run grounding checks against the real repos, interview the user on gaps,
  write the note, and snapshot round 1. Use when starting a new ticket or
  issue, initializing a spec, or "spec-init MOP-XXXX" / "spec-init #N". Use
  spec-sync for later rounds.
---

# Spec Init

`CORE` = `~/.claude/skills/spec-core`.

Arguments: `[ID]`. Optional.

1. Select the profile per `$CORE/SKILL.md` — from the ID, or from the current
   branch when no ID is given. If neither resolves, ask for the ID.
2. Read `$CORE/init.md` and the files it lists, then follow `init.md`.
