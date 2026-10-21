---
name: spec-post
description: >-
  Publish the consolidated spec note to its MOP Jira ticket or homelab
  Forgejo issue: overwrite the description with the current spec (stamped
  round + date) and post a comment with a curated subset of the private Open
  Questions, after a fresh-eyes challenge and four guards, behind one
  approval. Use when a spec round is ready for the PM, confirming the spec,
  publishing the spec or its questions, or "spec-post MOP-XXXX" /
  "spec-post #N". Requires the note from spec-init/spec-sync.
---

# Spec Post

`CORE` = `~/.claude/skills/spec-core`.

Arguments: `[ID]`. Optional.

1. Select the profile per `$CORE/SKILL.md` — from the ID, or from the current
   branch when no ID is given. If neither resolves, ask for the ID.
2. Read `$CORE/post.md` and the files it lists, then follow `post.md`.
