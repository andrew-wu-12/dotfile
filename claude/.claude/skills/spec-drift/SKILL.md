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

Fixes a gap the workflow has no other answer for: checking **spec against code
already written.** When a PM changes a field, rule, or endpoint mid-development,
code written for the earlier spec becomes silently wrong, and the mismatch
surfaces later in UAT. This skill diffs the spec's round snapshots, inspects
only what changed, and then checks the branch against that change.

With only one round, there is no delta to diff. But code can still silently
assume something the spec never actually stated — for example, "one reference
maps to exactly one shipment." No round comparison can catch that case, because
the assumption was never stated, let alone changed. Step 1b covers that case
instead.

## Prerequisites

- The monorepo (`$MOP_MONOREPO_PATH`) sits on the ticket's feature branch
  (usually `feature/MOP-XXXX`). Confirm with
  `git -C "$MOP_MONOREPO_PATH" rev-parse --abbrev-ref HEAD`. If it is not on
  that branch, check it out or ask the user.
- At least **one round** exists for the ticket (`specs/.rounds/MOP-XXXX/`).
  With zero rounds, there is nothing to check against. Tell the user to run
  `spec-sync` first.

## Workflow

### 1. Get the spec delta

```bash
~/bin/spec-round-diff.sh MOP-XXXX        # latest two rounds
~/bin/spec-round-diff.sh MOP-XXXX 3      # explicit: round-02 -> round-03
```

Exit code 2 means fewer than two rounds exist. Skip straight to **step 1b**
instead of steps 2-4 — no delta exists, so the round-diff path has nothing to
inspect.

Otherwise, a unified diff of `round-(N-1)` to `round-N` exists. **Run it, and
steps 2-4 below, inside a fresh subagent** — the raw round-diff text (and the
branch greps in step 3) have no reason to sit in the caller's context; only
the triaged step 4 report does. Give the subagent the ticket id, the two
commands above, and steps 2-4 verbatim. Require it to return only the step 4
report — drift / informational / aligned-and-omitted, each `path:line` — never
the raw unified diff or raw grep output. Continue reading below to know what
the subagent should do; the caller only consumes its final report.

### 1b. Fallback: cardinality ambiguity scan (only when step 1 exits 2)

No round exists to diff here, so this step does not hunt for drift. It hunts
for a *different* bug shape: code that silently assumes a 1:1 relationship the
spec never confirmed — or, worse, that the spec actually states is 1:N. Scope
the check to the **PR's own diff**, not the whole app. This is not a full spec
audit; it checks only what this PR actually touches:

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
3. Grep the single current spec round for both concepts together, then
   classify the result into one of three cases:
   - The spec explicitly confirms one-to-one (e.g. "唯一", "unique",
     "一個...對應一個"). This is **aligned** — do not report it.
   - The spec explicitly states or implies one-to-many (e.g. "多筆", "多個",
     "list", "multiple"), and the code still does a singular lookup. This is a
     **contradiction** — a confirmed mismatch even without a second round.
     Report it at that severity, not as "worth asking."
   - The spec says nothing about cardinality for that relationship either way.
     This is an **ambiguity** — flag it as worth confirming with the PM or
     business, not as a confirmed bug. Most unstated cardinality is genuinely
     fine; treat this as a nudge, not an accusation.
4. Cite every finding as `path:line`, using the same bar as the round-diff
   path.

Report (English), separate from step 4 below, most actionable first:
- **Contradiction** — spec explicitly says one-to-many, code assumes one-to-one.
  `path:line` plus the spec's own wording.
- **Ambiguity** — the spec is silent on cardinality for a relationship the
  code assumes is 1:1. Give `path:line` plus a one-line prompt: "worth
  confirming: can `<key>` map to more than one `<target>`?"
- If you find nothing: say so plainly. No single-record lookup in this diff
  assumes an unconfirmed relationship.
- **Never a blocker.** This takes the same posture as the drift-report
  findings below: surface the finding and let the user decide. Most singular
  lookups are correct; this check exists only to catch the cases where one
  silently isn't.

### 2. Identify the changed items

From the diff, pull the **concrete, code-mappable** changes — ignore prose churn:
- field **id / name** changed or renamed (e.g. `console_number_list` -> `consol_number_list`)
- field **type** changed (e.g. text -> multi-select)
- optional ↔ **required** flip, or validation rule added/changed
- **API endpoint** path / method / payload key changed
- **i18n key** changed
- result **column** added / removed / renamed
- **privilege** id changed

For each change, note the **old** value and the **new** value. The old value
is what you hunt for in code.

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

A changed item whose code already matches the new spec is **aligned** — do
not report it. Report only genuine contradictions. Cite every finding as
`path:line`.

### 4. Drift report

Run this step only when step 1 ran the round-diff path (steps 2-3). Report to
the user in English, most actionable first:
- **Drift** — code that now contradicts the new spec. Give `path:line` and
  the old-to-new change that caused it.
- **Informational** — items that changed but have no code yet. This is new
  work, not drift.
- If nothing contradicts: say so plainly. The round's changes are already
  reflected in code, or have no code surface yet.

This is a pre-ready guard. `/pr-ready` runs it, alongside its own review step,
before it flips the PR to ready. Surface findings; let the user decide.
