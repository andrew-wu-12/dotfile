---
name: spec-sync
description: >-
  Merge a new round of spec decisions into an existing spec artifact: re-fetch
  Jira, extract decisions from a pasted chat/verbal log, flag contradictions
  across Jira vs chat vs the current spec, rewrite to current truth, and snapshot
  the round. Use after a PM discussion or spec change, when reconciling updated
  requirements, or "spec-sync MOP-XXXX". Requires the note created by spec-init.
---

# Spec Sync → reconcile a new round

Fold a fresh round of decisions into the durable spec note. The spec lives in
three channels — Jira, chat/verbal, prototype — and chat is ephemeral. This skill
is the reconciliation the human does badly across three sources: it surfaces
contradictions instead of silently overwriting, and records every decision with
its source so the artifact stays trustworthy.

`SKILL_DIR` = `~/.claude/skills/spec-sync`.

## Prerequisites

- **VPN + `JIRA_TOKEN`** (`source ~/.zshrc`). Do not hard-gate on `scutil --nc list` — it false-negatives while the VPN is up; let the fetch surface real connectivity errors.
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

### 2. Re-fetch Jira

```bash
OUT=$(mktemp -d)
~/bin/fetch-ticket.sh MOP-XXXX "$OUT" > "$OUT/manifest.json"
```

Read new comments and any **new** attachments (Read the images). New prototype
images can silently change the spec — treat them as a decision source.

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

- Rewrite the `規格` sections to reflect resolved decisions (Traditional Chinese,
  same doc-* skills as spec-init).
- If an item was checked this round and came back **unchanged**, do not narrate
  that in `規格` (no "stayed the same as Round N" callouts, no unchanged-item
  prose). `規格` documents current truth only, not a diff log. Record the
  "checked, no change" fact as a Decision Log row instead if it's worth keeping.
- Any API contract in `後端規格` is a request/response JSON example (with
  `[MISSING]` placeholders where unknown), not a prose description of fields.
- `規格` speaks in business-level terms only: pages (by module + page name,
  never a route/URL), data fields, and API endpoints. No file paths, component
  names, function/hook names, or code constants (e.g. `configs/Foo.tsx`,
  `handleSaveStep`, `STEP_DISPATCH_EDIT`, `FormGroup.tsx`). If a decision is
  really about *how* to implement something (a library choice, a code
  pattern), it belongs in the Decision Log, not `規格` — `規格` states the
  observable behavior, not the implementation mechanism.
- Before writing any multi-fact sentence in `規格` (field tables included), list
  the discrete facts first, then keep that as a bullet list — don't fuse them
  back into one run-on sentence or a stuffed table cell. Table cells stay one
  line; a field needing more gets its own bullet group below the table.
- **Append** to Decision Log: one dated, source-tagged row per decision this round.
- **Append** a Round History entry summarizing what changed.
- Update Open Questions: check off answered ones, add newly surfaced ones.
- Bump `round` in frontmatter.

Decision Log and Round History are append-only — never rewrite history, only the
`規格` reflects current truth.

### 6. Snapshot the round

```bash
~/bin/spec-snapshot.sh MOP-XXXX   # creates round-NN
```

Run **last**, after the rewrite, so `round-NN.md` equals the end-of-round-N state
and `/spec-drift` (v2) can diff round-(N-1) against round-N for exactly this
round's change.

### 7. Report what changed

Tell the user (English): the decisions folded in and their sources, every
contradiction found and how it resolved, what is still open, and a one-line
"changed this round" summary. If any contradiction was pushed to Open Questions
unresolved, lead with that — it is the thing that needs their call.

## Rules

- NEVER silently overwrite a conflicting value — surface it in step 4 first.
- Most-recent-explicit wins; genuine ties become Open Questions, not guesses.
- Decision Log / Round History append-only; `規格` always current truth.
- `規格` never narrates unchanged items — that's what Decision Log is for.
- API contracts are payload/response JSON, not prose.
- List first, write second — multi-fact content is bullets, not run-on sentences
  or stuffed table cells.
- No file paths, component/function/constant names, or route/URLs in `規格` —
  pages are named by module + page name, behavior is described observably.
  Implementation mechanism belongs in the Decision Log, not `規格`.
- Spec body in Traditional Chinese; reporting to the user in English.
