# Drift → is the code still aligned with the spec?

Checks **spec against code already written**. When a spec round changes a
field, rule, endpoint, or config value mid-development, code written for the
earlier round becomes silently wrong. This step diffs the round snapshots,
inspects only what changed, and checks the branch against that change.

With only one round there is no delta, but the code can still disagree with
something the spec states — or assume something it never states. The
profile's one-round scan (step 5) covers that case.

Read first: the profile (its Drift section).

## Prerequisites

- The profile's code repo sits on the ticket's feature branch. Confirm with
  `git -C <repo> rev-parse --abbrev-ref HEAD`. If not, check it out or ask
  the user.
- At least **one round** exists in `$SPECS/.rounds/<id>/`. With zero
  rounds, there is nothing to check against — tell the user to run
  `spec-init` first.

## Workflow

### 1. Get the spec delta

```bash
~/bin/spec-round-diff.sh "$SPECS" <id>        # latest two rounds
~/bin/spec-round-diff.sh "$SPECS" <id> 3      # round-02 -> round-03
```

Exit code 2 means fewer than two rounds. Skip to **step 5**.

Otherwise run steps 2–4 as the profile says. When delegated: a fresh
subagent gets the ID, the commands above, and steps 2–4 verbatim, and
returns only the step 4 report — never the raw diff or raw grep output.

### 2. Identify the changed items

From the diff, pull the **concrete, code-mappable** changes — the profile
lists the kinds. Ignore prose churn. For each, note the **old** and **new**
value. The old value is what you hunt for in code.

### 3. Check the feature branch

For each changed item, grep the branch with the profile's search command,
then judge:

- **Rename / value change** → code still using the old value = drift.
- **Optional → required**, or a new rule → code path missing the new
  validation/guard = drift.
- **Removed item** → code still referencing it = drift.
- **Added item** → usually no code yet; informational, not drift.
- Code already matching the new spec → **aligned**; do not report it.

Cite every finding as `path:line`.

### 4. Drift report

In English, most actionable first:
- **Drift** — `path:line` and the old → new change that caused it.
- **Informational** — changed items with no code yet. New work, not drift.
- Nothing contradicts → say so plainly.

### 5. One-round scan (only when step 1 exits 2)

Run the profile's one-round scan, scoped to the **PR's own diff** (the
profile's diff command), not the whole repo. It reports:
- **Contradiction** — the spec explicitly states X, the diff does not-X.
  `path:line` plus the spec's own wording.
- **Soft finding** — the profile's non-contradiction category.
- Nothing found → say so plainly.

## Caller contract

`spec-ready` runs this as its drift gate. **Drift** blocks the flip. A
one-round **Contradiction** blocks only if the profile says so. Informational
and soft findings never block. Run standalone, this step only reports.
