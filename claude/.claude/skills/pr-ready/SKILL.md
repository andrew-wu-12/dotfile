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
two checks that catch different failures: `/code-review` (correctness bugs) and
`/spec-drift` (code that no longer matches a changed spec — the one that bites in
UAT). Drift is a **hard block**; review findings are **warnings**.

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

### 2. Spec-drift gate (BLOCKING)

Run the **spec-drift** skill for the ticket (it diffs the two latest spec rounds
and greps the branch for contradictions).

- **Drift found** → **STOP. Do not flip ready.** Report each contradiction with
  `path:line` and the old→new spec change that caused it. The fix is to update the
  code (or re-confirm the spec), then re-run `pr-ready`.
- **No drift** → gate passes, continue.
- **Can't run** (fewer than 2 spec rounds, or no spec artifact) → not a blocker.
  There was only ever one spec, so no drift is possible. Note it and continue.

### 3. Code-review (WARN-only)

Run the **code-review** skill on the diff. Surface every finding to the user as a
**warning** — do not block on them. The user may have valid reasons to ship and
address review comments in-thread.

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
- Code-review findings as a warning list (or "clean").

## Rules

- Spec-drift is the gate: **any** contradiction blocks the flip.
- Code-review never blocks — warn and proceed.
- Never assign reviewers.
- If the PR isn't a draft, or no PR exists, stop and say so — don't create one.
