---
name: doc-spec-interview
description: >-
  Ask the user about spec gaps before you write the spec note. Do not
  silently file every gap to Open Questions. spec-init uses this for
  missing/unstated ticket details; spec-sync uses this for unresolved
  contradictions. Do not invoke this skill on its own.
---

# Doc Spec Interview → ask before you file it

Some gaps have a fast answer. The developer running the skill often knows
it. Ask first. File to Open Questions only what the developer cannot answer.

## Scope

Only two kinds of gaps qualify:

- **spec-init** — missing/unstated ticket details (grounding check 2).
- **spec-sync** — unresolved contradictions (this round's new ones, plus every
  contradiction still unresolved from a prior round).

Do not run this step on any other finding.

## Ask, in batches of 4

Use `AskUserQuestion`. Each call asks up to 4 questions. If more than 4 gaps
are in scope, issue more batches. Do not cap the total or skip old
unresolved gaps.

Every question must offer an "I don't know / ask the PM" option. Never force
an answer.

## Record the outcome

- **Answered** → add one Decision Log row, `Source = dev`. Do not also add an
  Open Questions entry for it.
- **Deferred** ("ask the PM") → file to Open Questions exactly as today. A
  re-asked question that is deferred again stays in Open Questions, unchanged.

## If you cannot ask

If there is no interactive context (for example, a headless run), skip this
step. File every in-scope gap to Open Questions, as before.
