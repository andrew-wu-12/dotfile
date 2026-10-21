---
name: mop-spec-verify
description: >-
  Run the spec's test scenarios (測試案例情境) against the feature in a real browser
  (ego-browser) on a local `yarn serve` of the current worktree, and record one
  PASS / FAIL / INCONCLUSIVE row per scenario. spec-ready reads the
  record. Use when a feature is testable and you want to check it against the spec,
  "mop-spec-verify MOP-XXXX", "test the scenarios", "verify in the browser", or
  "mop-spec-verify MOP-XXXX 2 5" to rerun only some scenarios.
---

# Spec Verify — run the spec's test scenarios in a browser

## Words used in this skill

Each word below has one meaning in this file.

- **scenario** — one Precondition / Action / Expected Result block from the
  `### 3. 測試案例情境` section of the spec note.
- **row** — the recorded result of one scenario.
- **write scenario** — a scenario whose action creates, edits, deletes, submits,
  imports, approves, or uploads data.
- **clean FAIL** — the page shows a result that disagrees with Expected Result,
  and the evidence shows it with no doubt.
- **INCONCLUSIVE** — the run could not decide. Examples: no matching data, a
  login wall, a hidden page, a timeout, a write scenario that you did not approve.
- **stale** — a row whose `sha` is not `HEAD`, or whose `round` is not the
  current spec round.

## Why this skill exists

The other spec skills compare text: spec with spec, spec with code. None of them
runs the feature. This skill clicks through each scenario the way a tester does.

The result goes to a record file. `spec-ready` reads the record. It
never starts the browser run, because the run is slow and needs a running app.

Only a current **clean FAIL** blocks the flip. A browser run fails for many
reasons that are not defects. Those reasons give INCONCLUSIVE, and
INCONCLUSIVE only warns.

## Prerequisites

- Run inside the ticket's worktree. Confirm with `git rev-parse --show-toplevel`
  and `git rev-parse --abbrev-ref HEAD` (`feature/MOP-XXXX` or `hotfix/MOP-XXXX`).
- The spec note `~/personal/office-note/Specs/MOP-XXXX.md` exists, and its
  `### 3. 測試案例情境` section has at least one scenario. See
  `spec-core` (schema.md + profiles/mop.md). If no scenario exists, stop and tell the user.
- `ego-browser` is installed. Read the `ego-browser` skill for its API.

## Arguments

`mop-spec-verify MOP-XXXX [n ...]`. Each `n` is a scenario number. Without
numbers, run all scenarios.

## Paths

```bash
WT=$(git rev-parse --show-toplevel)
TICKET=MOP-XXXX
NOTE="$HOME/personal/office-note/Specs/$TICKET.md"
RESULT="$WORKTREE_ROOT/mop-console-monorepo/$TICKET.verify.json"
SHOTS="$WORKTREE_ROOT/mop-console-monorepo/$TICKET.verify"
SHA=$(git rev-parse HEAD)
```

The record sits next to the worktree, like `$TICKET.title`. It never shows in
`git status`. `wtd` deletes both paths on teardown.

## Workflow

### 1. Load the scenarios

Read `round:` from the frontmatter of the note. Read the `### 3. 測試案例情境`
section. Number the scenarios 1, 2, 3, … in the order they appear. A scenario
number is valid only inside one round. A new round makes each old row stale.

Keep only the numbers from the arguments, if the user gave numbers.

For each scenario, write down:

- the page (`{module_name} - {page_name}`),
- the precondition,
- the action,
- the expected result,
- whether it is a write scenario.

### 2. Ask for approval of the write scenarios

The local serve calls a shared backend. A write scenario changes shared data.

If the run has write scenarios, list them with their number and action. Then ask
once with `AskUserQuestion`: **All**, **None**, or a list of numbers in "Other".

A write scenario that you did not approve still runs up to the submit step. It
never submits. Its row is INCONCLUSIVE with the reason `write not approved`.

### 3. Resolve the apps to serve

```bash
git fetch origin main
git diff --name-only origin/main...HEAD | awk -F/ '$1=="apps"{print $2}' | sort -u
node -p "Object.keys(require('$WT/remotes.config')).join(' ')"
```

Keep each app from the diff that is a key of `remotes.config`. Drop `container`
and each `*-e2e` directory. The container always runs.

If the diff touches only `libs/`, map the spec's `{module_name}` to an app key.
If you cannot map it, ask the user which app to serve.

The serve command is `yarn serve --<app> --<app> ...`.

### 4. Start the serve

```bash
~/bin/tmux-serve.sh status    # <target>\t<status>\t<cmd>
```

Save the output as `PREV_TARGET` and `PREV_CMD`. Step 8 needs them.

- **The target is this worktree, the status is `online`, and the command has each
  app flag** — keep it. Go to step 5.
- **The target is a different worktree and the status is not `offline`** — ask the
  user with `AskUserQuestion` before you continue. Name the other worktree. The
  takeover stops its serve. If the user says no, stop.
- **Else** — start the serve:

```bash
~/bin/tmux-serve.sh start "$WT" "yarn serve --<app> --<app>"
~/bin/tmux-serve.sh wait 540
```

`wait` prints `online` (exit 0), `error` (exit 1, compile errors on stderr),
`offline` (exit 1), or `timeout` (exit 2). On `timeout`, run `wait 540` one more
time. On `error` or `offline`, stop and report the output. Then do step 8.

From here on, if any step stops the run, do step 8 before you stop.

### 5. Check the login

Run one short ego-browser script in this context. Open `http://localhost:4200`.
Wait for the page to load. Take a snapshot.

If the page is a login page, call `task.handOff()`. Tell the user to log in in
ego-browser. Ask them to answer when they are done. Then check again. Never type
credentials yourself.

### 6. Run the scenarios in a fresh subagent

Snapshots and DOM text are large. Only the verdict table must come back to this
context. Run a **fresh** `general-purpose` subagent in the foreground. Do not
use a fork. Give it:

- the worktree path `$WT` and the base URL `http://localhost:4200`,
- each scenario from step 1, with its number,
- the approved write scenarios from step 2,
- the screenshot directory `$SHOTS` (create it first with `mkdir -p`),
- the instructions below, verbatim.

> Read the `ego-browser` skill first. Use one task space for the whole run. Call
> `task.finish()` at the end.
>
> **Find the page.** First grep the route config in `$WT/apps/<app>/src` for the
> page's route (`path:` entries near the page component). Open
> `http://localhost:4200/<route>`. If you find no route, or the route does not
> show the page, open the page from the app menu by its name.
>
> **Meet the precondition.** Search the UI for a record that matches the
> precondition (list pages, filters, search). Use a record that already exists.
> Do not create data for a precondition. If you find no record, do not run the
> scenario. Return it as NEEDS_DATA and describe the record you need.
>
> **Run the action.** Follow the action step by step. For a write scenario that
> is not in the approved list, stop before the final submit. Return it as
> INCONCLUSIVE with the reason `write not approved`.
>
> **Compare.** Compare the page with Expected Result. Take one screenshot of the
> final state to `$SHOTS/<n>-<short-slug>.png`. Take more screenshots only when a
> mid-step state is part of the expected result.
>
> **Verdicts.**
> - PASS — the page shows the expected result.
> - FAIL — the page shows a different result. Write the expected text and the
>   actual text side by side.
> - INCONCLUSIVE — you could not decide. Give the reason. If a page, menu entry,
>   or button is absent and the code in `$WT` has a `permissionId` for it, use
>   the reason `hidden by privilege: <permissionId>`.
> - NEEDS_DATA — no record matches the precondition.
>
> Never log in. If a login page appears, stop and return each remaining scenario
> as INCONCLUSIVE with the reason `login required`.
>
> Return only this table, one row per scenario, and no raw snapshots:
>
> `n | title | verdict | expected | actual | reason | screenshots | created ids`
>
> `created ids` lists each record that a write scenario created, by its business
> id (for example a shipment number).

**NEEDS_DATA rows.** Collect all of them. Ask the user once, in one message, for
a record id for each. Run a second fresh subagent for those scenarios only, with
the ids in the precondition. A scenario that is still without data is
INCONCLUSIVE with the reason `no test data`.

**`login required` rows.** Do step 5 again. Then run a fresh subagent for those
scenarios only.

### 7. Confirm each FAIL

A FAIL blocks the flip. A false FAIL costs a lot. Check each FAIL in this
context before you record it:

1. Read each screenshot of the row with the `Read` tool.
2. Compare the screenshot with the spec's Expected Result, not with the
   subagent's `expected` text.
3. Keep the FAIL only if the screenshot shows the wrong result with no doubt.
4. Else change the verdict to INCONCLUSIVE. Write the reason, for example
   `FAIL not confirmed: page still loading in screenshot`.

### 8. Restore the serve

Do this step after each run, also after a run that stopped early.

- The serve was not changed in step 4 — do nothing.
- `PREV_TARGET` is empty — leave the serve as it is. Report it.
- Else — start the old serve again. Use `PREV_CMD`. If `PREV_CMD` is empty, omit
  it; the worktree's `WORKSPACE_SERVE_CMD` is then used.

```bash
~/bin/tmux-serve.sh start "$PREV_TARGET" ${PREV_CMD:+"$PREV_CMD"}
```

Do not wait for it to be online.

### 9. Write the record

Read `$RESULT` if it exists. Replace the rows of the scenarios in this run. Keep
the other rows as they are, with their own `sha` and `round`. Write the file
back:

```json
{
  "ticket": "MOP-XXXX",
  "rows": [
    {
      "n": 1,
      "title": "<short scenario title>",
      "verdict": "PASS | FAIL | INCONCLUSIVE",
      "reason": "<empty for PASS>",
      "expected": "<text>",
      "actual": "<text>",
      "screenshots": ["<absolute path>"],
      "created": ["<business id>"],
      "sha": "<HEAD at run time>",
      "round": 3,
      "at": "<YYYY-MM-DDTHH:MM>"
    }
  ]
}
```

Sort the rows by `n`.

### 10. Report

Report these items:

- A table with one line per scenario of this run: number, verdict, reason.
- Each FAIL with expected and actual text and its screenshot path.
- Each INCONCLUSIVE row with what fixes it. For `hidden by privilege`, name
  `/mop-check-privilege MOP-XXXX`.
- Each record that a write scenario created, by id. Tell the user that the skill
  did not delete them.
- The serve state after step 8.
- The rerun command for the rows that are not PASS:
  `/mop-spec-verify MOP-XXXX <n> <n>`.

## Rules

- Never type credentials. A login page goes to the user through `handOff()`.
- Never submit a write scenario that the user did not approve.
- Never create data to meet a precondition. Ask the user for a record id.
- Never delete data that a write scenario created.
- Never take over another worktree's serve without a yes from the user.
- Always do step 8, also after a run that stopped early.
- A FAIL goes to the record only after step 7 confirms it.
- Never write a row before its scenario ran. A run that stopped early records
  only the rows it finished.
