---
name: uat-gate
description: >-
  Before a prod (uat -> main) merge, verify every feature/hotfix ticket merged
  into the uat branch is in "UAT VERIFIED" status. Use when about to deploy a
  uat branch to prod, checking release readiness, "is this release UAT verified",
  or "uat-gate MOP-XXXX". A guard, not a blocker — reports and flags, you decide.
---

# UAT Gate → pre-prod ticket-status check

Step 10 of the workflow: before merging a `uat/*` branch to `main`, make sure all
related tickets have passed UAT. This finds the feature/hotfix tickets actually in
the release (merged into the uat branch, not yet in main) and checks each one's
Jira status.

## Prerequisites

- `JIRA_TOKEN` + VPN (`source ~/.zshrc`).
- Run against the monorepo; the script cds to `$MOP_MONOREPO_PATH`.

## Usage

```bash
~/bin/uat-gate.sh                 # current monorepo branch (must be uat/*)
~/bin/uat-gate.sh uat/MOP-24959   # explicit uat branch
~/bin/uat-gate.sh MOP-24959       # shorthand -> uat/MOP-24959
```

Override the target status if the workflow name ever changes:

```bash
UAT_GATE_STATUS="UAT VERIFIED" ~/bin/uat-gate.sh MOP-24959
```

## How it scopes "related tickets"

Tickets = the `MOP-XXXX` in each `feature/…` or `hotfix/…` **merge-commit branch
name** within `origin/main..origin/<uat-branch>`. Comparing against `main` means
anything already released drops out automatically. Squash-merged PRs without a
`Merge pull request` commit are not detected — if the count looks low, check the
branch's merge strategy.

## Reading the result

- `✔ MOP-XXXX  UAT VERIFIED` — passed.
- `✗ MOP-XXXX  <status>` — not yet verified (e.g. `Develop`, `UAT TESTING`).
- Exit `0` = all verified; exit `3` = at least one isn't.

It's a **guard**: exit 3 is a warning, not a hard stop. Surface the ✗ tickets to
the user and let them decide whether a legitimate exception applies before the
prod merge. Related workflow statuses seen in MOP: `UAT`, `UAT TESTING`,
`UAT VERIFIED`, `Verification Fail`, `Develop`, `PROD`, `Done`.
