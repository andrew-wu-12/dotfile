---
name: spec-drift
description: >-
  Detect spec-vs-code drift for a MOP ticket or homelab issue: diff the two
  latest spec-round snapshots and, for each changed item, grep the feature
  branch for code that now contradicts the new spec. With only one round,
  scans the PR's own diff instead (MOP: unstated 1:1 cardinality; homelab:
  config the spec states but the diff contradicts). Use after a spec-sync
  round, before marking a PR ready, when checking whether written code still
  matches the spec, or "spec-drift MOP-XXXX" / "spec-drift #N". Feeds the
  ready check.
---

# Spec Drift

`CORE` = `~/.claude/skills/spec-core`.

Arguments: `[ID]`. Optional.

1. Select the profile per `$CORE/SKILL.md` — from the ID, or from the current
   branch when no ID is given. If neither resolves, ask for the ID.
2. Read `$CORE/drift.md` and the files it lists, then follow `drift.md`.
