---
name: doc-spec-challenge
description: >-
  Adversarially challenge the 規格 section for internal contradictions,
  unstated edge cases, cross-reference gaps, and undefined terms before it
  gets published. Used by spec-post before the write path — not meant to be
  invoked on its own.
---

# Doc Spec Challenge → catch what drafting couldn't see

The session that drafted 規格 shares its own blind spots — if it missed a
contradiction while writing, it will miss the same contradiction while
reading it back. This skill hands the extracted 規格 to a **fresh subagent**
with no chat history, so it isn't primed with the same assumptions.

Scope is bounded to four checks. This is not another pass at `pr-ready`'s
code-vs-spec job or `spec-drift`'s round-diff job — it never looks at code,
only at 規格 against itself.

## Workflow

### 1. Extract 規格

Same slice `spec-post` step 4 already takes:

```bash
awk '
  /^## /    { p = 0 }
  /^## 規格/ { p = 1 }
  p
' "$NOTE" > "$OUT/spec-body.md"
```

### 2. Delegate to a fresh subagent

Give it `spec-body.md`, `doc-spec-body`'s rules (so it knows what 規格 is
allowed to say), and the note's **Decision Log** and **Open Questions**
sections (so it can suppress gaps that are already known and deferred —
step 4 below). It gets nothing else: no chat log, no round history, no
codebase access.

Instruct it to find only:

- **Contradictions** — two places in 規格 describe the same field, rule, or
  flow differently.
- **Missing negative/edge cases** — a test-scenario block with no error
  path, or a field with validation implied elsewhere but never stated in
  its own scenario.
- **Cross-reference gaps** — a field named in an API request/response
  example that isn't in the field table, or vice versa.
- **Undefined terms** — a business term used as settled fact with no
  Decision Log row backing it.

Nothing else. Nothing about implementation, code, or Jira state.

### 3. Cite evidence

Each finding must quote the exact 規格 text it applies to (not a
paraphrase) and state the problem in one line. No evidence, no finding.

### 4. Suppress known gaps

Drop any finding that the **Decision Log** already has a row for, or that
**Open Questions** already lists (checked or not — a checked item is
resolved, not just tracked, but either way it isn't new). A gap already
being tracked isn't a fresh finding; re-surfacing it here is noise
`spec-post`'s own guards don't need.

### 5. Verdict

Report back:

- `READY` — nothing survived step 4.
- `REVISE` — the surviving findings, each with its quote and one-line
  problem statement.

## Caller contract

`spec-post` runs this before its existing guards. On `READY`, proceed
silently — a clean run gets no extra noise. On `REVISE`, show the findings
once and ask: fix now (back to `spec-sync` or a manual edit), or post
anyway. This step **warns, it does not block** — same posture as
`spec-post`'s other four guards.
