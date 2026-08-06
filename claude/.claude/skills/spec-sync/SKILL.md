---
name: spec-sync
description: >-
  Merge new decisions into an existing spec: re-fetch Jira, extract decisions
  from a pasted chat/verbal log, flag contradictions across Jira/chat/current
  spec, rewrite to current truth, and snapshot the round. Use after a PM
  discussion or spec change, when reconciling updated requirements, or
  "spec-sync MOP-XXXX". Requires the note from spec-init.
---

# Spec Sync → reconcile a new round

Fold a fresh round of decisions into the durable spec note. The spec lives in
three channels: Jira, chat or verbal discussion, and the prototype. Chat is
ephemeral. This skill surfaces contradictions between the channels and records
trustworthy decisions with their sources.

`SKILL_DIR` = `~/.claude/skills/spec-sync`.

## Prerequisites

- **`JIRA_TOKEN`** (`source ~/.zshrc`). The fetch surfaces a clean error if the token is wrong.
- `specs/MOP-XXXX.md` **must already exist**. If not, stop and tell the user to run
  `spec-init` first.
- **The pasted chat/verbal log.** It arrives as the skill argument or in the
  user's message. If it is missing, ask the user to paste it — a rough summary
  is fine; no formatting is required. A sync with no chat log is valid when
  only Jira changed. State that this is the case, then proceed with Jira and
  the prototype only.

## Workflow

### 1. Load current state

Read `specs/MOP-XXXX.md` — especially the current `規格`, `Decision Log`, and
`Open Questions`. Note the current `round` from frontmatter (new round = +1).

### 2. Re-fetch Jira (delegated)

Delegate the fetch to a **general-purpose subagent** using `tool-ticket-get`.
Run it in the foreground — step 3 needs its output first. Give it the ticket
ID and the note's current state: which comments and attachments it already
reflects.

For anything new since the note's last round, require its report to list each
comment verbatim (author, date, text) and the **file paths** of any new
attachments. Do not accept a description of what the attachments show — the
report needs the actual paths.

Then **you** (main thread) `Read()` every new attachment image directly. A new
prototype image can silently change the spec. Treat every new image as a
decision source.

### 3. Extract decisions from the chat log

Pull concrete decisions from the pasted dump: field changes, rule changes, endpoint
changes, scope cuts. Ignore chatter. Tag each with source `chat`.

### 4. Cross-source contradiction check — the core step

For each changed item, compare its value across the three sources and the
current spec. **List every contradiction explicitly.** Example:

> `eta` field — current spec: optional · Jira comment (07-14): optional · chat
> (07-15): **required**. → chat is newer and explicit → resolve to required.

Resolution rule: prefer the **most recent explicit** decision. If two sources
conflict and neither has clear recency or authority, **do not guess**. Add the
conflict to Open Questions and flag it to the user instead of silently
picking one.

### 5. Rewrite to current truth

- Rewrite the `規格` sections using `doc-spec-body`'s conventions (language,
  field/API/test-scenario formats, business-level terms only, decision-log
  boundary, bullet formatting).
- If an item was checked this round and came back **unchanged**, leave its
  entry in `規格` exactly as it was. Do not narrate that you checked it — no
  "unchanged since Round N" callouts, no unchanged-item prose. If the "checked,
  no change" fact is worth keeping, record it as a Decision Log row instead.
- `規格` documents current truth only. It is not a diff log. State facts; do
  not narrate them.
- **Append** to Decision Log (append-only): one dated, source-tagged row per decision this round.
- **Append** a Round History entry summarizing what changed (append-only).
- Update Open Questions: check off answered ones, add newly surfaced ones.
- Bump `round` in frontmatter.

### 6. Snapshot the round

```bash
~/bin/spec-snapshot.sh MOP-XXXX   # creates round-NN
```

Run this **last**, after the rewrite, so `round-NN.md` matches the
end-of-round-N state. This lets `/spec-drift` diff round-(N-1) against round-N
for exactly this round's change.

### 7. Report what changed

List the following in English:
- New decisions with sources
- One-line "changed this round" summary.
- Unresolved Open Questions

