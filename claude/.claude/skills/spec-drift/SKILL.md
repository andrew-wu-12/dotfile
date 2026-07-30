---
name: spec-drift
description: >-
  Detect spec-vs-code drift after a spec round: diff the two latest spec-round
  snapshots and, for each CHANGED item, grep the feature branch for code that now
  contradicts the new spec. With only one round, falls back to scanning the PR
  diff for unstated data-relationship cardinality (e.g. code assumes 1:1 where
  the spec never says). Use before flipping a PR to ready, after a spec-sync
  round, when checking whether already-written code still matches the spec, or
  "spec-drift MOP-XXXX". Feeds /pr-ready.
---

# Spec Drift → is the code still aligned with the spec?

Fixes the second alignment problem the workflow has no answer for: **spec ↔ code
already written.** When a PM changes a field/rule/endpoint mid-development, code
written for the earlier spec is silently wrong and surfaces in UAT. This diffs the
spec's round snapshots and only inspects what changed, then checks the branch.

With only one round there's no delta to diff, but code can still silently assume
something the spec never actually said (e.g. "one reference maps to exactly one
shipment") — no round comparison will ever catch that, since it was never stated,
let alone changed. Step 1b covers that case.

## Prerequisites

- The monorepo (`$MOP_MONOREPO_PATH`) is on the ticket's feature branch (usually
  `feature/MOP-XXXX`). Confirm with `git -C "$MOP_MONOREPO_PATH" rev-parse --abbrev-ref HEAD`;
  if not, check it out or ask.
- At least **one round** exists for the ticket (`specs/.rounds/MOP-XXXX/`). With
  zero, there's nothing to check against at all — tell the user to run
  `spec-sync` first.

## Workflow

### 1. Get the spec delta

```bash
~/bin/spec-round-diff.sh MOP-XXXX        # latest two rounds
~/bin/spec-round-diff.sh MOP-XXXX 3      # explicit: round-02 -> round-03
```

Exit 2 = fewer than two rounds → skip straight to **step 1b** instead of steps
2-4 (no delta exists, so there's nothing for the round-diff path to inspect).
Otherwise you get a unified diff of `round-(N-1)` -> `round-N` and continue with
steps 2-4 below; step 1b does not apply.

### 1b. Fallback: cardinality ambiguity scan (only when step 1 exits 2)

There's no round to diff, so this doesn't hunt for drift — it hunts for a
*different* bug shape: code that silently assumes a 1:1 relationship the spec
never confirmed (or, worse, that the spec actually says is 1:N). Scope to the
**PR's own diff**, not the whole app — this is not a full spec audit, only
checking what this PR actually touches:

```bash
git -C "$MOP_MONOREPO_PATH" diff main...HEAD -- 'apps/<app>/**/*.ts' 'apps/<app>/**/*.tsx'
```

1. In that diff, find single-record lookups: `.find(...)` on an array, or a
   function typed to return `T | undefined` / a bare `T` (not `T[]`), where:
   - the lookup key is an identifier-shaped field/param (`*_id`, `*_no`,
     `*_number`, `*Id`, `*Number`, or equivalent), and
   - the returned type is a multi-field domain object, not a primitive or enum
     (skip trivial type-guard/enum lookups — they're not relationship lookups).
2. For each match, name the **key field** (what it searches by) and the
   **target entity** (what it returns).
3. Grep the single current spec round for both concepts together and classify:
   - Spec explicitly confirms one-to-one (e.g. "唯一", "unique", "一個...對應一個")
     → **aligned**, do not report.
   - Spec explicitly states or implies one-to-many (e.g. "多筆", "多個", "list",
     "multiple") and the code still does a singular lookup → **contradiction**:
     a confirmed mismatch even without a second round, report it with that
     severity (not just "worth asking").
   - Spec says nothing about cardinality for that relationship either way →
     **ambiguity**: flag it as worth confirming with the PM/business, not as a
     confirmed bug — most unstated cardinality is genuinely fine, this is a
     nudge, not an accusation.
4. Cite every finding as `path:line`, same bar as the round-diff path.

Report (English), separate from step 4 below, most actionable first:
- **Contradiction** — spec explicitly says one-to-many, code assumes one-to-one.
  `path:line` plus the spec's own wording.
- **Ambiguity** — spec is silent on cardinality for a relationship the code
  assumes is 1:1. `path:line` plus a one-line "worth confirming: can `<key>` map
  to more than one `<target>`?"
- If nothing found: say so plainly — no single-record lookups in this diff assume
  an unconfirmed relationship.
- **Never a blocker** — same posture as drift-report findings below, surface and
  let the user decide. Most code doing a singular lookup is correct; this exists
  to catch the cases where it silently isn't.

### 2. Identify the changed items

From the diff, pull the **concrete, code-mappable** changes — ignore prose churn:
- field **id / name** changed or renamed (e.g. `console_number_list` -> `consol_number_list`)
- field **type** changed (e.g. text -> multi-select)
- optional ↔ **required** flip, or validation rule added/changed
- **API endpoint** path / method / payload key changed
- **i18n key** changed
- result **column** added / removed / renamed
- **privilege** id changed

For each, note the **old** value and the **new** value — the old value is what you
hunt for in code.

### 3. Check the feature branch for contradictions

For each changed item, grep the branch (scope to the ticket's app/module):

```bash
grep -rnI "<old-value-or-affected-identifier>" "$MOP_MONOREPO_PATH/apps/<app>" \
  --include='*.ts' --include='*.tsx' --include='*.vue'
```

Judge per change type:
- **rename / value change** → code still using the **old** value = drift.
- **optional → required** → code path missing the new validation/guard = drift.
- **removed field/column/endpoint** → code still referencing it = drift.
- **added item** → usually no existing code yet; note as informational, not drift.

A changed item whose code already matches the new spec is **aligned** — do not
report it. Only report genuine contradictions. Cite every finding as `path:line`.

### 4. Drift report

Only when step 1 ran the round-diff path (steps 2-3), report to the user
(English), most actionable first:
- **Drift** — code that now contradicts the new spec, each with `path:line` and the
  old→new change that caused it.
- **Informational** — items that changed but have no code yet (new work, not drift).
- If nothing contradicts: say so plainly — the round's changes are already
  reflected in code (or have no code surface yet).

This is a pre-ready guard: it's what `/pr-ready` runs, alongside its own owned
review step, before flipping the PR to ready. Surface findings; the user decides.

## Rules

- Round-diff path: inspect **only the delta** — never re-audit unchanged spec
  items. The old value is the search key; matching code = aligned = silent.
- Ambiguity-scan path (1b): scope to the **PR's diff only** — never an
  unprompted full-spec audit. Contradiction and ambiguity findings are both
  **WARN-only**, never a block, same as drift findings.
- No guessing: a finding needs a real `path:line`, not a hunch.
- Report in English; the spec rounds themselves stay Traditional Chinese.
