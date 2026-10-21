---
name: spec-flow
description: >-
  Drive one MOP ticket or homelab issue through the spec flow automatically:
  read where it stands (spec note, rounds, posts, tracker activity, branch
  commits, PR state), run every step that can run now (spec-init, spec-sync,
  spec-post, spec-drift, mop-spec-verify, spec-ready, mop-spec-document),
  and stop at the next human gate with what unblocks it. Re-run to resume.
  Use for "spec-flow", "next step for MOP-XXXX", "where is this ticket",
  "continue the spec flow", or "spec-flow MOP-XXXX <chat log>" after a
  discussion.
---

# Spec Flow

`CORE` = `~/.claude/skills/spec-core`.

Arguments: `[ID] [chat log]`. Both optional.

1. Select the profile per `$CORE/SKILL.md` — from the ID, or from the current
   branch when no ID is given. If neither resolves, ask for the ID.
2. Read `$CORE/flow.md` and the files it lists, then follow `flow.md`.
