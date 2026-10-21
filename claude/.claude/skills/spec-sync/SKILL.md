---
name: spec-sync
description: >-
  Merge new decisions into an existing spec note (MOP Jira ticket or homelab
  Forgejo issue): re-fetch the tracker, extract decisions from a pasted chat
  log, flag contradictions across tracker/chat/current spec, interview the
  user on gaps, rewrite to current truth, and snapshot the round. Use after a
  PM or design discussion, when requirements changed, or "spec-sync
  MOP-XXXX" / "spec-sync #N". Requires the note from spec-init.
---

# Spec Sync

`CORE` = `~/.claude/skills/spec-core`.

Arguments: `[ID] [chat log]`. Both are optional.

1. Select the profile per `$CORE/SKILL.md` — from the ID, or from the current
   branch when no ID is given. If neither resolves, ask for the ID.
2. Read `$CORE/sync.md` and the files it lists, then follow `sync.md`.
