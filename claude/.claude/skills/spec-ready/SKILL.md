---
name: spec-ready
description: >-
  Check that a feature PR (MOP monorepo or homelab) is ready for review: the
  spec is posted, the code agrees with the spec, extra gates pass (MOP: the
  browser run of the test scenarios), no code refers to a removed
  identifier, and the diff has no defects. If the gates pass, flip the draft
  PR to ready; on an already-ready PR, only report. Use when a feature is
  done, "spec-ready", "is this PR ready", or to re-check a PR after pushing
  fixes. Never assigns reviewers or merges.
---

# Spec Ready

`CORE` = `~/.claude/skills/spec-core`.

Arguments: `[ID]`. Optional.

1. Select the profile per `$CORE/SKILL.md` — from the ID, or from the current
   branch when no ID is given. If neither resolves, ask for the ID.
2. Read `$CORE/ready.md` and the files it lists, then follow `ready.md`.
