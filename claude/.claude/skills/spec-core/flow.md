# Flow → run the next steps until a human gate

Work out where one ticket stands from its artifacts, run every step that can
run now, and stop at the next human gate with a clear "waiting on X". The
user re-runs it to resume. There is no state file and no polling: every
signal below is read fresh from the note, the branch, the PR, and the
tracker.

Read first: `schema.md`, the profile (its Tracker, Ready, and Flow sections).

## Rules

- Run each step by invoking its skill (`spec-init`, `spec-sync`,
  `spec-post`, `spec-drift`, `spec-ready`, and the profile's extra steps) in
  this session. A step's own interview and approval prompts are never
  skipped, batched, or pre-answered. Every external write — tracker post,
  PR flip, config PR — goes through that step's approval, unchanged.
- After each step, re-read the signals and re-evaluate the table from the
  top. Never run the same step twice in one invocation; if the table points
  back at a step that already ran, stop and report why.
- Never write code. Implementation is the user's.
- If the user declines an approval or aborts a step, stop there and report.

## Signals

Read all of these before choosing a row. Report each in the final summary.

| Signal | How |
|--------|-----|
| chat log | the skill argument after the ID, or pasted in the user's message |
| note | `$SPECS/<id>.md` exists |
| round, posted | frontmatter `round` and the highest `posted[].round` |
| new activity | tracker comments **not yours** (the profile Tracker's "You"), created after the latest of: the last `posted[].date`, the last Round History date, and the last Decision Log row date (profile Tracker fetch) |
| waiting | unchecked Open Questions items with a `⏳` marker |
| commits | the profile Flow section's commit count on the feature branch |
| PR | the profile's PR lookup: none / draft / ready / merged / closed (closed = without merging) |
| shipped | the profile's Flow "shipped" check |

## Stage table

Pick the **first** row that matches.

| # | Condition | Action |
|---|-----------|--------|
| 0 | chat log given (first pass only) | **`spec-sync`** with the log |
| 1 | no note | **`spec-init`** |
| 2 | `round` > highest posted round | **`spec-post`** |
| 3 | new activity | **`spec-sync`** — ask for a chat log, or "none" |
| 4 | waiting items **and** commits == 0 | **STOP** — "waiting on <bucket>: <items>" |
| 5 | commits == 0 | **STOP** — "spec settled; implement now" |
| 6 | shipped | the profile's shipped action |
| 7 | PR is none | **STOP** — "open a PR for <branch>" (never create one) |
| 8 | PR is merged | **STOP** — "merged into <base>; waiting for the release" |
| 9 | PR is closed | **STOP** — "PR closed without merging" |
| 10 | PR is draft or ready | **`spec-drift`** → the profile's pre-ready steps → **`spec-ready`** |

Row 4 applies only before implementation starts. Once the branch has
commits, open questions stop blocking: list them in the report and carry on
to rows 6–10, since the drift and ready checks are where a late answer
matters.

Row 10 runs `spec-drift` before `spec-ready` so its report is visible on
its own; `spec-ready` runs it again as gate 3 — that rerun is cheap and
keeps `spec-ready` self-contained. After row 10, stop: the flow is done
until new commits, new tracker activity, or a merge.

## Report

In English:
- The signals as read.
- Each step run this invocation, with its one-line outcome.
- Where it stopped and why: the gate, and what unblocks it (who answers,
  what to run, what to push).
- Open questions still waiting, grouped by bucket, when any exist.
