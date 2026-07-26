---
name: spec-drift
description: >-
  Detect spec-vs-code drift after a spec round: diff the two latest spec-round
  snapshots and, for each CHANGED item, grep the feature branch for code that now
  contradicts the new spec. Use before flipping a PR to ready, after a spec-sync
  round, when checking whether already-written code still matches the spec, or
  "spec-drift MOP-XXXX". Feeds /pr-ready.
---

# Spec Drift → is the code still aligned with the spec?

Fixes the second alignment problem the workflow has no answer for: **spec ↔ code
already written.** When a PM changes a field/rule/endpoint mid-development, code
written for the earlier spec is silently wrong and surfaces in UAT. This diffs the
spec's round snapshots and only inspects what changed, then checks the branch.

## Prerequisites

- At least **two rounds** exist for the ticket (`specs/.rounds/MOP-XXXX/`). If
  only one, there's no delta — tell the user to run `spec-sync` first.
- The monorepo (`$MOP_MONOREPO_PATH`) is on the ticket's feature branch (usually
  `feature/MOP-XXXX`). Confirm with `git -C "$MOP_MONOREPO_PATH" rev-parse --abbrev-ref HEAD`;
  if not, check it out or ask.

## Workflow

### 1. Get the spec delta

```bash
~/bin/spec-round-diff.sh MOP-XXXX        # latest two rounds
~/bin/spec-round-diff.sh MOP-XXXX 3      # explicit: round-02 -> round-03
```

Exit 2 = fewer than two rounds (stop, run spec-sync). Otherwise you get a unified
diff of `round-(N-1)` -> `round-N`.

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

Report to the user (English), most actionable first:
- **Drift** — code that now contradicts the new spec, each with `path:line` and the
  old→new change that caused it.
- **Informational** — items that changed but have no code yet (new work, not drift).
- If nothing contradicts: say so plainly — the round's changes are already
  reflected in code (or have no code surface yet).

This is a pre-ready guard: it's what `/pr-ready` runs alongside `/code-review`
before flipping the PR to ready. Surface findings; the user decides.

## Rules

- Inspect **only the delta** — never re-audit unchanged spec items.
- The old value is the search key; matching code = aligned = silent.
- No guessing: a finding needs a real `path:line`, not a hunch.
- Report in English; the spec rounds themselves stay Traditional Chinese.
