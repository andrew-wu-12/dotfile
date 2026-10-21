# Challenge → catch what drafting couldn't see

The session that drafted the spec body shares its blind spots: a
contradiction it missed while writing, it misses again while reading back.
So hand the extracted body to a **fresh subagent** with no chat history.

Four checks only. It never looks at code or the tracker — only at the body
against itself. Code-vs-spec is `spec-drift`'s job.

## Workflow

### 1. Extract the body

```bash
awk -v h="<profile body heading>" '
  /^## /           { p = 0 }
  $0 == h || index($0, h " ") == 1 { p = 1 }
  p
' "$NOTE" > "$DRAFTS/spec-body.md"
```

### 2. Delegate to a fresh subagent

Give it `spec-body.md`, `body.md` plus the profile's body rules (so it knows
what the body may say), and the note's **Decision Log** and **Open
Questions** (so it can drop known gaps). Nothing else: no chat log, no round
history, no codebase access.

It finds only:

- **Contradictions** — two places describe the same field, rule, or flow
  differently.
- **Missing negative/edge cases** — a scenario or verification step with no
  error path, or a validation implied in one place but never stated where it
  applies.
- **Cross-reference gaps** — the profile's cross-reference pairs.
- **Undefined terms** — a term used as settled fact with no Decision Log row
  behind it.

### 3. Cite evidence

Each finding quotes the exact body text it applies to (not a paraphrase)
and states the problem in one line. No quote, no finding.

### 4. Drop known gaps

Drop any finding that a Decision Log row or an Open Questions item (checked
or not) already covers.

### 5. Verdict

- `READY` — nothing survived step 4.
- `REVISE` — the surviving findings, each with its quote and problem line.

## Caller contract

On `READY`, proceed silently. On `REVISE`, show the findings once and ask:
fix now (`spec-sync` or a manual edit), or continue anyway. This **warns, it
does not block**.
