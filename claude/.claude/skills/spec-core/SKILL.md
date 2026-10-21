---
name: spec-core
description: >-
  Shared method for the spec-* flow (schema, body rules, per-domain profiles).
  Read by spec-* skills; never invoked on its own.
disable-model-invocation: true
---

# Spec Core

The domain-neutral method behind the `spec-*` skills, plus one profile per
domain. A `spec-*` skill reads the step file it needs and the profile its
ticket ID selects. This file is only an index.

`CORE` = `~/.claude/skills/spec-core`.

## Profiles

Select the profile by ID shape. With no ID, read the current branch name.

| ID shape | Branch shape | Profile |
|----------|--------------|---------|
| `MOP-1234` | `feature/MOP-1234` | `$CORE/profiles/mop.md` |
| `#12` or `12` | `feature/12-<slug>` | `$CORE/profiles/hl.md` |

The profile supplies every domain fact: paths, language, tracker, terms,
templates. The step files never name a domain. When a step file says
"the profile's X", read X from the profile.

## Step files

| File | What it holds |
|------|---------------|
| `schema.md` | note location, frontmatter, sections, row formats |
| `body.md` | what the spec body may and may not say |
| `interview.md` | the ask-until-owned loop for gaps and change reasons |
| `init.md` | the init procedure (`spec-init`) |
| `sync.md` | the sync procedure (`spec-sync`) |
| `challenge.md` | fresh-eyes check of the body against itself |
| `post.md` | the post procedure (`spec-post`) |
| `drift.md` | the spec-vs-code drift check (`spec-drift`) |
| `ready.md` | the PR readiness check and flip (`spec-ready`) |
| `flow.md` | the orchestrator: detect the stage, run steps, stop at gates (`spec-flow`) |
