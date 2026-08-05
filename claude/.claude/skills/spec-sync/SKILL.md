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
three channels — Jira, chat/verbal, prototype — and chat is ephemeral. This skill
surfaces contradictions, and records trustworthy decisions with their sources.

`SKILL_DIR` = `~/.claude/skills/spec-sync`.

## Prerequisites

- **`JIRA_TOKEN`** (`source ~/.zshrc`). The fetch surfaces a clean error if the token is wrong.
- `specs/MOP-XXXX.md` **must already exist**. If not, stop and tell the user to run
  `spec-init` first.
- **The pasted chat/verbal log.** It comes as the skill argument or in the user's
  message. If none was provided, ask the user to paste it (a rough summary is fine
  — no formatting required). It is valid to sync with no chat log when only Jira
  changed; say so and proceed with Jira + prototype only.

## Workflow

### 1. Load current state

Read `specs/MOP-XXXX.md` — especially the current `規格`, `Decision Log`, and
`Open Questions`. Note the current `round` from frontmatter (new round = +1).

### 2. Re-fetch Jira (delegated)

Delegate the fetch to a **general-purpose subagent**, run in the foreground
(step 3 depends on its output). Give it the ticket ID and the note's current
state (what comments/attachments it already reflects); have it run:

```bash
OUT=$(mktemp -d)
~/bin/fetch-ticket.sh MOP-XXXX "$OUT" > "$OUT/manifest.json"
```

Require its report to list, for anything new since the note's last round: each
comment verbatim (author, date, text), and the **file paths** of any new
attachments — not a description of what they show.

Then **you** (main thread) `Read()` every new attachment image directly. New
prototype images can silently change the spec — treat them as a decision source.

### 3. Extract decisions from the chat log

Pull concrete decisions from the pasted dump: field changes, rule changes, endpoint
changes, scope cuts. Ignore chatter. Tag each with source `chat`.

### 4. Cross-source contradiction check — the core step

For each item that changed, compare the value across the three sources and the
current spec. **List every contradiction explicitly**, e.g.:

> `eta` field — current spec: optional · Jira comment (07-14): optional · chat
> (07-15): **required**. → chat is newer and explicit → resolve to required.

Resolution rule: prefer the **most recent explicit** decision. If two sources
conflict with no clear recency/authority, **do not guess** — add it to Open
Questions and flag it to the user rather than silently picking one.

### 5. Rewrite to current truth

- Rewrite the `規格` sections with the following rules:
  - Written in Traditional Chinese.
  - Uses the same doc-* skills as spec-init.
  - If an item was checked this round and came back **unchanged**, leave its entry
    in `規格` exactly as-is — do not narrate that it was checked (no "unchanged
    since Round N" callouts, no unchanged-item prose). Record the "checked, no
    change" fact as a Decision Log row instead if it's worth keeping.
  - `規格` documents current truth only, not a diff log — it is never narrated,
    only stated.
  - `後端規格` should be demonstrated  with **Request/Response** JSON example, not descriptions. Show `[MISSING]` for unknown value.
  - Speaks in **business-level terms only**
    - **Display**: pages (`{module_name} - {page_name}`), data fields, i18n keys, and API endpoints.
    - **Avoid**: file paths, component/function/hook names, route/URL, or code constants.
  - If a decision is really about *how* to implement something (a library choice,
    a code pattern), it belongs in the Decision Log, not `規格` — `規格` states
    the observable behavior, not the implementation mechanism.
  - When writing a multi-fact sentence in `規格`, keep it short and use a bullet
    list. A table cell longer than one line gets its own bullet group below the
    table instead.
- **Append** to Decision Log (append-only): one dated, source-tagged row per decision this round.
- **Append** a Round History entry summarizing what changed (append-only).
- Update Open Questions: check off answered ones, add newly surfaced ones.
- Bump `round` in frontmatter.

### 6. Snapshot the round

```bash
~/bin/spec-snapshot.sh MOP-XXXX   # creates round-NN
```

Run **last**, after the rewrite, so `round-NN.md` equals the end-of-round-N state
and `/spec-drift` (v2) can diff round-(N-1) against round-N for exactly this
round's change.

### 7. Report what changed

List the following in English:
- New decisions with sources
- One-line "changed this round" summary.
- Unresolved Open Questions

