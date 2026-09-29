---
name: pr-ready
description: >-
  Check that a feature PR is ready for review. The skill checks four things: the spec
  is posted to Jira, the code agrees with the spec, no code refers to a removed
  identifier, and the diff has no defects. If the gates pass, the skill flips the
  draft PR to ready. The skill also checks a PR that is already ready; then it only
  reports. Use when a feature is done and you want to mark the PR ready for review,
  "pr-ready", "is this PR ready", or to re-check a PR after pushing fixes. The skill
  does not assign reviewers. CODEOWNERS and the user do that.
---

# PR Ready — check that a PR is ready for review

## Words used in this skill

Each word below has one meaning in this file. Use the same word for the same thing.

- **flip** — change the PR from draft to ready.
- **gate** — a step that can block the flip.
- **block** — prevent the flip.
- **finding** — one defect or one risk that a step found.
- **warning** — a finding that does not block.
- **drift** — code that disagrees with the current spec.
- **marker** — a file that holds the SHA of the last commit that this skill checked.

## Why the check is separate from the flip

This is step 7 of the workflow. The check is the useful part of this skill. The flip
is only the result of a check that passes.

Therefore you can run the check at any time. You can run it after the PR is ready.
This is necessary. Reviewers find defects after the flip as often as before it. A
gate that runs only at the flip is a gate that almost never runs.

Run one context step, then four gates. The order puts the cheap and certain gates
first. A `grep` can block the PR, so the expensive review must not run first.

| # | Step | Blocks? | Finds |
| - | ---- | ------- | ------- |
| 1b | CI results and comments | no — context | false trust in green checks; repeated findings |
| 2 | Is the spec posted? | **yes** | reviewers who read an old spec |
| 3 | Does the code disagree with the spec? | **yes** | code written for an old spec |
| 4 | Broken identifier references | **yes**, if confirmed | callers that you renamed |
| 5 | Code defects | no — warns | logic defects |

Step 1b blocks nothing. It limits what the later steps can claim. It shows which
tests CI ran. It shows what the reviewers said.

Note: `/code-review` is a billed feature. Only the user can start it. Claude Code
always blocks model invocation of it. A call always fails with
`disable-model-invocation`. This is by design. Do not try it. Step 5 does its own
review.

## Prerequisites

- The worktree is on the feature branch of the ticket. The PR is open. A draft PR and
  a ready PR are both correct.
- `gh` is authenticated. VPN and `JIRA_TOKEN` give the spec gates their Jira data.
- Run `git fetch origin main` first. Each diff below uses `origin/main...HEAD`. An old
  local `main` makes the diff too large and hides the real changes.

## Workflow

### 1. Get the PR and select a mode

```bash
gh pr view --json number,isDraft,title,url,headRefName,body
```

Select the mode from `isDraft`:

- **`true` — FLIP mode.** Run gates 2 to 5. Then step 6 flips the PR.
- **`false` — RECHECK mode.** Run gates 2 to 5. Report the result. Skip step 6. Never
  run `gh pr ready --undo`. A PR that returns to draft leaves the reviewers in an
  open thread. Report the result and let the user decide.
- **No PR** — stop and tell the user. Do not create a PR.

Take the `MOP-XXXX` id from the branch name. Each spec gate needs this id.

### 1b. Read the CI results and the comments

```bash
gh pr checks <number>
gh pr view <number> --json comments,reviews
```

Get four things. None of them blocks. All of them limit what the later steps can
claim.

1. **The state of each check.** A red required check is a warning. It does not block.
   The check can be flaky or unrelated. Give the name of the check. Let the user
   decide.
2. **The tests that CI does not run.** This is the important half. Read
   `.github/workflows/`. Do not assume. In this repo, PR CI runs unit tests
   (`nx affected -t test`, `continuous_integration.yml`) and builds
   (`nx affected -t build`, `knip_pr_build.yml`). PR CI runs no Cypress e2e test. No
   workflow under `.github/` refers to Cypress. The e2e job is
   `.jenkins/e2e_testing/jenkinsfile`. That job checks out `branch: 'main'`. The
   `E2E_TESTING_TAG` variable gates that job. Therefore a diff can break an e2e test
   and all checks stay green. Write one line for the report that names the tests CI
   did not run. Never give a green check as evidence for a test that did not run.
3. **Open bot requests.** Bot comments hold team rules. CI often reports `pass` for
   these rules. One example applies here. The shared-component doc check needs a
   Confluence link in the References block of the PR description for each `libs/**`
   change. Its GitHub check reports `pass`. Its comment reports that the link is
   absent. Only the comment text is correct. If the link is absent, report a warning
   and name `/changelog-confluence`.
4. **The review comments that exist.** Make an index of them. Steps 4 and 5 use the
   index. Do not report a finding that a reviewer already gave. Do not report a
   finding that someone already fixed. Mark each finding that you report as **new**,
   **already-raised**, or **already-fixed**. RECHECK mode needs this most, because a
   PR in RECHECK mode is under review.

Then read the marker. The marker shows what is new since the last check.

```bash
GATE_FILE="$(git rev-parse --git-dir)/pr-ready-gate"   # per-worktree, never committed
cat "$GATE_FILE" 2>/dev/null                            # SHA of the last gated commit
git log --oneline <that-sha>..HEAD                      # what landed since
```

If the marker exists and equals `HEAD`, tell the user. The gates already ran on this
tree. The user can ask for the earlier report.

If the marker exists and differs from `HEAD`, scope steps 4 and 5 to
`<marker>..HEAD`. If no marker exists, scope steps 4 and 5 to `origin/main...HEAD`.

Write `HEAD` to `$GATE_FILE` after the gates finish. Do not write it before. A run
that stops early must not mark the work as checked.

### 2. Gate: is the spec posted? (BLOCKING)

Reviewers depend on this gate. No other skill does this check. Step 3 compares the
spec with the code. No step compares the spec with the version that the reviewers
read.

The note can hold more rounds than Jira holds. Then the code is correct and a
reviewer still reports findings against an old spec. This costs one full review
cycle.

```bash
SPECS="$HOME/personal/office-note/Specs"
NOTE="$SPECS/MOP-XXXX.md"
```

See `doc-spec-schema` for this path and the frontmatter fields below. Read the
frontmatter of the note. Compare three things.

1. **The round number and the posted rounds.** Compare frontmatter `round: N` with
   the highest `round:` in the `posted:` list. If `N` is larger than the highest
   posted round, unposted rounds exist.
2. **The PR body.** Read the body. Does the body describe the current scope? If a
   round removed an item from the scope, does the body still promise that item?
3. **The PR title and the ticket title.** A reviewer reads the title first. A title
   is also the last text that anyone corrects after a scope change.

Verdicts:

- **Unposted rounds exist — block the flip.** Report the gap as
  `round: N, last posted: M`. Name each change between round M and round N that a
  reviewer would read incorrectly. To correct this, run `/spec-post`. Then run
  `pr-ready` again.
- **A round removed an item, and the title or the body still promises that item —
  block the flip.** The correction is cheap. Edit the body. Ask the PM to change the
  title. This correction prevents the most common review comment: "is this feature
  completely unimplemented?"
- **The highest posted round equals the current round, and the body and the title
  match the scope** — the gate passes.
- **No spec note exists** — this does not block. Note it and continue.

RECHECK mode cannot block a flip, because the flip already happened. In RECHECK mode
this gate blocks the verdict of the report instead. Report the PR as not ready for
review.

### 3. Gate: does the code disagree with the spec? (BLOCKING for drift)

Run the **spec-drift** skill for the ticket. The skill takes one of two paths. With
2 or more spec rounds, it compares the last two rounds. Then it greps the branch for
code that disagrees. With 1 round, it reads the PR diff instead. Then it looks for
data relationships with an unstated cardinality. That is step 1b of spec-drift.

- **The skill found drift** (the round-comparison path) — **block the flip.** Report
  each disagreement. Give `path:line`. Give the old spec value and the new spec
  value. To correct this, change the code. You can also confirm the spec again. Then
  run `pr-ready` again.
- **The skill found no drift** — the gate passes. Continue.
- **The skill reported a contradiction or an ambiguity** (the single-round path) —
  this does not block. Add these items to the warnings from step 5.
- **No spec note exists** — this does not block. Note it and continue.

### 4. Gate: search for broken identifier references (BLOCKING if confirmed)

A review that reads only the diff cannot find this defect class. This step is a
separate search.

Example: you rename a DOM id. The file that breaks is the caller. You did not change
the caller. Therefore the caller is not in the diff. More careful reading of the diff
cannot find it.

Test directories and e2e directories break most often. They are never in an app
diff. PR CI often does not run them.

This step is a `grep`. It is not a judgment. Run it even if the diff is small.

**4a. Removed identifiers and renamed identifiers.** Collect each identifier that
appears on a `-` line and on no `+` line:

```bash
git diff origin/main...HEAD | grep '^-' | grep -oE "(id|name|data-testid)='[^']+'|#[a-zA-Z_][a-zA-Z0-9_.-]*"
```

The regular expression is a start. It does not cover all identifiers. Add these by
hand: exported symbols, i18n keys, API field names, CSS tokens, `classNamePrefix`
tokens, `localStorage` keys, and privilege ids.

**The repo-wide search and its triage are delegated to a fresh subagent.** A grep of
the whole repository for a field name hits every unrelated module that uses the same
name — one real run returned 10 hits, only 2 were defects. That raw dump has no
reason to sit in this context; only the triaged verdicts do. Give the fresh subagent
the identifier list from 4a, the old→new mapping for each rename, each newly-added
selector token, and the two numbered checks below, then have it run and triage both
searches — it must never return raw grep output, only verdicts:

1. **4a — removed/renamed identifiers.** For each identifier, run:
   ```bash
   ~/bin/identifier-scope-check.sh '<identifier>' "$MOP_MONOREPO_PATH"
   ```
   This buckets every repo-wide hit into out-of-scope (auto-dismissed, no file
   opened) vs in-scope (with grep context attached) — an app-local diff is bucketed
   by directory prefix (plus the matching `-e2e` dir); a `libs/` change instead
   traces which files actually import the changed lib's resolved alias, since a
   shared lib is meant to be consumed from any app and prefix-bucketing would
   wrongly dismiss real cross-app callers. Judge only the in-scope hits it prints —
   trust its out-of-scope bucketing, do not re-check those by hand. A reference is
   broken only if it points to the same module that the diff renamed. The same name
   in a different feature is a different field — not a defect. Never change a hit
   before tracing it to the renamed identifier.
2. **4b — selectors that now match two elements.** This defect needs no removal. An
   added element is enough. For each new selector token (a shared `classNamePrefix`,
   a CSS class, or a `data-testid` pattern), count the matches before and after the
   change. If the count goes from 1 to 2 or more, find each call site that uses that
   selector and check whether it expects one element. A bare `.click()`, `.type()`,
   or `.should('have.value')` expects one element; `.first()`, `.eq()`, and
   `within()` set a scope. A call site without a scope is now broken. This is the
   same defect shape as the cardinality check in spec-drift — there the shape
   applies to data relationships, here to selectors.

Require the subagent to return one verdict per identifier/selector, `path:line` only:

- **Confirmed.** The reference points to the identifier that was removed. Or the
  call site does a single-element operation on a selector that now matches two
  elements. This result is mechanical, like drift. It is not a judgment.
- **Not confirmed.** The name belongs to an unrelated field. Or the code is dead. Or
  the call site already has a `.first()` scope.

**Verdicts, back in this context.** A grep hit alone is not a defect, so keep these
two apart.

- **Confirmed — block the flip.** Give `path:line` and the identifier.
- **Not confirmed — report a warning.** Add these items to the warnings from step 5.
- **Read the CI coverage before you trust a green check.** PR CI may not run the test
  suite that holds the broken code. Then a green check proves nothing. Write this in
  the report. Do not imply that CI checked the fix.

Name the replacement identifier when you report a correction for 4a. Give the reason.
A rename often has more than one possible target. The wrong target can add a required
field or a dependency that the old target did not have.

### 5. Review the code for defects (WARN-only)

You cannot start `/code-review` from here. See the note above. Do not try it. Do not
invent a review of unknown depth.

Instead, start a fresh subagent. Give it the diff from the scope in step 1b, and
have it apply the checklist below. A review that only asks "is this correct?"
misses the first four items. Therefore this file states them.

- **Effect re-invocation.** Read each new or changed `useEffect`. React StrictMode
  runs `mount`, then `cleanup`, then `mount` again in development. Does the setup
  code initialize each value that the cleanup code removed? Look at refs and flags.
  Can a value keep a state from the first cleanup during the second mount?
- **Interaction between components at run time.** Does the diff change a component
  that runs at the same time as another component? Do both components use the same
  state? Example: a modal opens, and a loop or a listener in a second component
  continues below the modal. Read one level past the changed files if you must.
- **Check the value that arrives, not the type.** Do this for each new or changed
  validator, schema, or type guard.
  1. Find the value that the field holds when the code runs. Do not trust the type.
  2. Follow the value from the API to the form. Read each layer that changes it.
  3. In this repo, `convertNullToString` (`libs/shared/util/buildable-utils`) changes
     each API `null` to `''`. It changes all levels of the object. Therefore `''` is
     the empty value for each field. `null` is not the empty value. `undefined` is
     not the empty value.
  4. A new schema that is not a string schema is therefore incorrect, unless it first
     transforms `''`. This applies to `Yup.number()`, `Yup.date()`, and
     `Yup.array()`. `.nullable()` does not correct this. `Yup.number()` casts `''` to
     `NaN`. Then the type check fails.
  5. List three cases for the field: the empty value, `null`, and an absent value.
  6. Check if the submit button depends on the schema. If it does, the form stays
     invalid. The user sees no way to continue. This is worse than one field message.
  7. Grep for two more signals. First: does nearby code already test for `=== ''` on
     this field? Then someone found this defect before. Second: does the error text
     show the English yup type error instead of the i18n message? Then the cast
     failed, not the rule that you wrote.
- **New defects inside a correction.** Read the diff if the diff corrects an earlier
  review finding. Does the correction leave a second item without a purpose? Example:
  the code still refers to a value, but the value no longer does its original work.
  Read the change that the correction made. Do not only confirm that the first defect
  is gone.
- Look for other defects. Use the same standard. Skip small items that a linter or
  the type checker reports.

Report each finding as a warning. Do not block. The user can have a good reason to
merge and to answer the review comments in the thread.

Mark each finding against the index from step 1b: **new**, **already-raised**, or
**already-fixed**. A second run must not repeat a settled item.

Tell the user that they can run `/code-review` themselves for a deeper review. That
review is billed. Do not run it for them.

### 6. Flip the PR to ready (FLIP mode only)

Do this only if gates 2, 3, and 4 all passed.

```bash
gh pr ready <number>
```

Report the warnings first. Then flip the PR. **Do not assign reviewers.** CODEOWNERS
requests the owners of the owned paths. The user assigns the other reviewers.

Skip this step in RECHECK mode. The PR is already ready. There is nothing to flip.

### 7. Report

Report these items:

- **The mode**: FLIP or RECHECK. If a marker existed, give the number of commits
  since the last check.
- **The result**: the PR is now ready, with its URL. Or the PR is still a draft,
  because a gate blocked it. Or the PR was already ready, and you only checked it.
- **The verdict of each gate**, one by one: passed, blocked, or skipped with a
  reason. A gate that did not run is not a gate that passed. Keep the two apart.
- **The CI coverage** from step 1b: the state of the checks, and one line that names
  the tests CI did not run for this diff. Give this line even if each check is green.
  A green check with an untested suite is the case that the user must know about.
- **The warnings**, as one list: the findings from step 5, the ambiguity items from
  spec-drift, the hits from step 4 that you did not confirm, and each open bot
  request. An example of a bot request is an absent Confluence link. Write "clean" if
  the list is empty. Mark each item as new, already-raised, or already-fixed.

Then write `HEAD` to `$GATE_FILE`.

## Rules

- **Never return a ready PR to draft.** RECHECK mode reports. It does not change the
  state of the PR.
- **Three gates block the flip**: step 2 (the spec is not posted), step 3 (the
  round-comparison path found drift), and step 4 (a confirmed broken reference). Each
  one of them blocks the flip alone.
- The hits from step 4 that you did not confirm never block. The single-round output
  of spec-drift never blocks. That output also uses the words "contradiction" and
  "ambiguity", but it is a different check. Do not confuse it with a gate.
- The findings from step 5 never block. Report them and continue.
- **Never limit the grep in step 4 to the app that you edited.** The value of the
  step is in the directories that the diff does not contain.
- A green check is not evidence for a test suite that CI does not run. Read the
  coverage first. Report the gap even if each check is green.
- The GitHub check of a bot can report `pass` while its comment reports a failure.
  Trust the comment text. Do not trust the check.
- Do not report a finding that a reviewer already gave or that someone already fixed.
  Mark it against the index from step 1b instead.
- Never assign reviewers.
- If no PR exists, stop and tell the user. Do not create a PR.
