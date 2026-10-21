# Ready → check that a PR is ready for review

## Words used in this file

Each word has one meaning here. Use the same word for the same thing.

- **flip** — change the PR from draft to ready.
- **gate** — a step that can block the flip.
- **block** — prevent the flip.
- **finding** — one defect or one risk that a step found.
- **warning** — a finding that does not block.
- **drift** — code that disagrees with the current spec.
- **marker** — a file that holds the SHA of the last commit this check ran on.

## Why the check is separate from the flip

The check is the useful part. The flip is only the result of a check that
passes. So the check runs at any time, including after the PR is ready:
defects are found after the flip as often as before it, and a gate that runs
only at the flip almost never runs.

One context step, then the gates. Cheap, certain gates go first — a `grep`
can block the PR, so the expensive review must not run first.

| # | Step | Blocks? | Finds |
| - | ---- | ------- | ----- |
| 1b | CI results (and review comments, if the profile has reviewers) | no — context | false trust in green checks; repeated findings |
| 2 | Is the spec posted? | **yes** | reviewers reading an old spec |
| 3 | Does the code disagree with the spec? | **yes**, per `drift.md` | code written for an old round |
| 3x | The profile's extra gates | per profile | per profile |
| 4 | Broken identifier references | **yes**, if confirmed | callers you renamed |
| 5 | Code defects | no — warns | logic defects |

`/code-review` is a billed feature. Only the user can start it; model
invocation always fails with `disable-model-invocation`. Do not try it.
Step 5 does its own review.

Read first: `drift.md`, the profile (its Ready section).

## Prerequisites

- The worktree is on the ticket's feature branch, and the PR is open. Draft
  and ready are both valid starting points.
- The profile's PR CLI is authenticated.
- Run `git fetch origin main` first. Every diff below uses
  `origin/main...HEAD`; a stale local `main` bloats the diff and hides the
  real change.

## Workflow

### 1. Get the PR and select a mode

Run the profile's PR view command and read its draft signal:

- **Draft — FLIP mode.** Run gates 2 to 5, then step 6 flips the PR.
- **Ready — RECHECK mode.** Run gates 2 to 5 and report. Skip step 6.
  **Never return a ready PR to draft** — that leaves an open thread with
  nothing watching it. Report and let the user decide.
- **No PR** — stop and tell the user. Do not create one.

Take the ID from the branch name. Every spec gate needs it.

### 1b. Read the CI results (and review comments)

Run the profile's CI command. None of this blocks; all of it limits what
later steps can claim.

1. **The state of each check.** A red check is a warning, not a block — it
   can be flaky or unrelated. Name it and let the user decide.
2. **What CI does not run.** Read the repo's workflow files; do not assume.
   The profile records what was true last time — confirm it. Write one line
   for the report naming what CI did not run. Never give a green check as
   evidence for something CI never ran.
3. **If the profile has reviewers:** its bot-request rules, and an index of
   existing review comments. Steps 4 and 5 mark each finding against the
   index as **new**, **already-raised**, or **already-fixed**, so a second
   run never repeats a settled item.

Then read the marker:

```bash
GATE_FILE="$(git rev-parse --git-dir)/pr-ready-gate"   # per-worktree, never committed
cat "$GATE_FILE" 2>/dev/null                            # SHA of the last gated commit
git log --oneline <that-sha>..HEAD                      # what landed since
```

If the marker equals `HEAD`, tell the user the gates already ran on this
tree. If it differs, scope steps 4 and 5 to `<marker>..HEAD`. With no
marker, scope them to `origin/main...HEAD`.

Write `HEAD` to `$GATE_FILE` after the gates finish — not before. A run that
stops early must not mark the work as checked.

### 2. Gate: is the spec posted? (BLOCKING)

The note can hold more rounds than the tracker shows. Then the code is right
and a reviewer still reports findings against an old spec.

Read the note's frontmatter (`schema.md`) and compare:

1. **Current round vs. posted rounds.** `round: N` against the highest
   `round:` in `posted:`. If `N` is larger, unposted rounds exist.
2. **The PR body.** Does it describe the current scope? If a round removed
   an item, does the body still promise it?
3. **The PR title and the ticket title.** The title is read first and
   corrected last after a scope change.

Verdicts:

- **Unposted rounds exist — block.** Report `round: N, last posted: M` and
  each change between M and N a reviewer would misread. Fix: `spec-post`,
  then `spec-ready` again.
- **A round removed an item and the title/body still promise it — block.**
  Edit the body; get the title corrected.
- **Highest posted round == current round, and body/title match scope** —
  passes.
- **No spec note** — does not block. Note it and continue.

In RECHECK mode this gate cannot block a flip that already happened; it
blocks the report's verdict instead ("not ready for review").

### 3. Gate: does the code disagree with the spec?

Run `drift.md` for the ID and apply its caller contract:

- **Drift** — block. Report `path:line` and old → new spec value. Fix the
  code or re-confirm the spec via `spec-sync`, then `spec-ready` again.
- **One-round Contradiction** — blocks only if the profile's Drift section
  says so; otherwise a warning.
- **Informational / soft findings** — warnings.
- **No spec note** — does not block.

### 3x. The profile's extra gates

Run each extra gate the profile's Ready section lists, with its own
verdicts.

### 4. Gate: broken identifier references (BLOCKING if confirmed)

A review that reads only the diff cannot find this: the caller you broke
is, by definition, not in the diff. Test and e2e directories break most
often and are rarely in the diff. This is a search, not a judgment — run it
even for a small diff.

1. Collect each identifier that appears on a `-` line and on no `+` line,
   with the profile's pattern plus the profile's by-hand list.
2. Search the **whole repo** for each — never only the module you edited —
   with the profile's search method (delegated or inline). A delegated
   search returns verdicts only, never raw grep output.
3. Judge each hit:
   - **Confirmed** — the reference points at the removed/renamed identifier
     (or the profile's other confirmed shapes). Mechanical, like drift.
   - **Not confirmed** — same name in an unrelated context, dead code, or
     already scoped.

Verdicts:

- **Confirmed — block.** `path:line`, the identifier, and the replacement
  name with the reason — a rename often has more than one possible target.
- **Not confirmed — warning.**

Read the CI coverage before trusting a green check: if CI does not run the
suite holding the broken code, a green check proves nothing. Say so.

### 5. Review the code for defects (WARN-only)

Apply the profile's review checklist to the diff from step 1b's scope,
delegated or inline as the profile says. A review that only asks "is this
correct?" misses the checklist items, which is why the profile states them.
Also look for other defects at the same standard; skip what a linter or
type checker reports.

Report each finding as a warning. Never block — the user can have a good
reason to merge and follow up. Tell the user they can run `/code-review`
themselves for a deeper, billed pass.

### 6. Flip (FLIP mode only)

Only if every blocking gate passed. Report the warnings first, then run the
profile's flip command. **Never assign reviewers**, and follow the
profile's merge rule. Skip in RECHECK mode.

### 7. Report

- **Mode**: FLIP or RECHECK; with a marker, the commit count since the last
  check.
- **Result**: now ready (URL), still draft because a gate blocked, or
  already ready and only checked.
- **Each gate's verdict**: passed, blocked, or skipped with a reason. A gate
  that did not run is not a gate that passed.
- **CI coverage**: check states plus the "what CI did not run" line, always —
  even when every check is green.
- **Warnings**, as one list: step 5 findings, non-blocking drift items,
  extra-gate warnings, unconfirmed step-4 hits, open bot requests. "clean"
  if empty. With reviewers, mark each new / already-raised / already-fixed.

Then write `HEAD` to `$GATE_FILE`.

## Rules

- Never return a ready PR to draft. RECHECK reports; it never changes PR
  state.
- Each blocking gate blocks alone: 2, 3 (per `drift.md`), the profile's
  blocking extra gates, and 4 (confirmed only).
- Unconfirmed step-4 hits, soft drift findings, and step 5 findings never
  block.
- A green check is not evidence for a suite CI does not run.
- A bot's check can report `pass` while its comment reports a failure.
  Trust the comment.
- Never assign reviewers. If no PR exists, stop; do not create one.
