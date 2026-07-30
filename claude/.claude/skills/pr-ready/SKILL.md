---
name: pr-ready
description: >-
  Finish a feature PR: run spec-drift and code-review, then flip the draft PR to
  ready — but BLOCK on any spec-vs-code drift. Use when a feature is done and you
  want to mark the PR ready for review, "pr-ready", or "is this PR ready".
  Does not assign reviewers (CODEOWNERS / manual handles that).
---

# PR Ready → gated draft-to-ready

Step 7 of the workflow, with a gate. Before flipping a draft PR to ready, run the
two checks that catch different failures: an owned review pass (correctness bugs)
and `/spec-drift` (code that no longer matches a changed spec — the one that bites
in UAT). Drift is a **hard block**; review findings are **warnings**.

Note: the real `/code-review` (and `/code-review ultra`) is a billed,
user-triggered feature that is permanently blocked from model invocation — calling
it here always fails with `disable-model-invocation`, by design, not a fluke.
Don't attempt it. Step 3 below owns its own review instead of trying to delegate
to it.

## Prerequisites

- Monorepo (`$MOP_MONOREPO_PATH`) on the ticket's feature branch with an open
  **draft** PR (created by `checkout-ticket.sh`).
- `gh` authenticated; VPN + `JIRA_TOKEN` for the drift check's Jira context.

## Workflow

### 1. Resolve the PR

```bash
gh pr view --json number,isDraft,title,url,headRefName
```

If it's already ready (not draft), say so and stop. Note the `MOP-XXXX` from the
branch name for the drift check.

### 2. Spec-drift gate (BLOCKING for drift; WARN-only for ambiguity)

Run the **spec-drift** skill for the ticket. With 2+ spec rounds it diffs them
and greps the branch for contradictions; with only 1 round it instead scans the
PR diff for unstated data-relationship cardinality (spec-drift's step 1b).

- **Drift found** (round-diff path) → **STOP. Do not flip ready.** Report each
  contradiction with `path:line` and the old→new spec change that caused it. The
  fix is to update the code (or re-confirm the spec), then re-run `pr-ready`.
- **No drift** → gate passes, continue.
- **Contradiction or ambiguity found** (single-round ambiguity-scan path) → not a
  blocker. Fold these into the warnings presented alongside step 3's findings.
- **No spec artifact at all** → not a blocker. Note it and continue.

### 3. Code-review (WARN-only)

The real `/code-review` can't be triggered from here (see note above) — don't try,
and don't improvise a review of unpredictable depth. Instead, launch a
general-purpose subagent against the PR's diff with this checklist. A plain "does
this look right" read structurally misses the first three, which is why they're
spelled out:

- **Effect re-invocation correctness**: for any new/changed `useEffect`, does it
  behave correctly under React StrictMode's dev-only `mount → cleanup → mount`?
  Specifically — does setup fully re-initialize anything cleanup tore down (refs,
  flags), or can a value get stuck from a stale cleanup on the second mount?
- **Cross-component runtime interaction**: does this diff touch a component that
  can run concurrently with another one touching the same state (e.g. a
  modal/overlay opening while a background loop/listener from a sibling component
  keeps running underneath it)? Look one level beyond the changed files if needed.
- **Regression-in-the-fix**: if this diff is itself a fix for an earlier review
  finding, does fixing it silently orphan something else that was already working
  (e.g. a value that's still referenced but no longer serves its original
  purpose)? Diff the fix's own change, don't just confirm the original finding is
  gone.
- Standard correctness/bug scan otherwise, same bar as before (skip nitpicks a
  linter/typechecker would catch).

Surface every finding to the user as a **warning** — do not block on them. The
user may have valid reasons to ship and address review comments in-thread. Also
mention that they can run the real `/code-review` themselves afterward for deeper
(billed) coverage — don't run it for them.

### 4. Flip to ready

Only if the drift gate passed:

```bash
gh pr ready <number>
```

Present the code-review warnings first, then flip. **Do not assign reviewers** —
CODEOWNERS auto-requests owners on owned paths, and the user assigns the rest by
hand.

### 5. Report

- PR is now **ready** (with its URL), or **still draft** because drift blocked it.
- Drift gate result (passed / blocked / skipped-why).
- Step 3 findings, plus any spec-drift ambiguity-scan contradiction/ambiguity
  findings, as one combined warning list (or "clean").

## Rules

- Spec-drift's round-diff **drift** is the only hard gate: **any** drift blocks
  the flip. Its single-round ambiguity-scan output (also labeled
  "contradiction"/"ambiguity" but a different, non-blocking check) never blocks
  — don't confuse the two.
- Step 3's review findings never block — warn and proceed.
- Never assign reviewers.
- If the PR isn't a draft, or no PR exists, stop and say so — don't create one.
