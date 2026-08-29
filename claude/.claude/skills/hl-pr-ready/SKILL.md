---
name: hl-pr-ready
description: >-
  Check that a homelab feature PR is ready for review. The skill checks four
  things: the spec is posted to the Forgejo issue, the code agrees with the
  spec, no config/code refers to a removed identifier, and the diff has no
  defects. If the gates pass, the skill flips the draft PR to ready. The
  skill also checks a PR that is already ready; then it only reports. Use
  when a homelab feature is done and you want to mark the PR ready,
  "hl-pr-ready", "is this PR ready", or to re-check a PR after pushing fixes.
---

# HL PR Ready — check that a homelab PR is ready for review

## Words used in this skill

Each word below has one meaning in this file.

- **flip** — change the PR from draft to ready.
- **gate** — a step that can block the flip.
- **block** — prevent the flip.
- **finding** — one defect or one risk that a step found.
- **warning** — a finding that does not block.
- **drift** — code/config that disagrees with the current spec.
- **marker** — a file that holds the SHA of the last commit this skill checked.

## Why the check is separate from the flip

The check is the useful part of this skill. The flip is only the result of
a check that passes. You can run the check at any time, including after the
PR is already ready — you are the only reviewer, and you find defects in
your own diff after the flip as often as before it. A gate that runs only
at the flip is a gate that almost never runs.

Run one context step, then four gates. Cheap and certain gates go first — a
`grep` can block the PR, so the review step must not run first.

| # | Step | Blocks? | Finds |
| - | ---- | ------- | ------- |
| 1b | CI results | no — context | false trust in a green check |
| 2 | Is the spec posted? | **yes** | reviewers (future-you) reading a stale spec |
| 3 | Does the code disagree with the spec? | **yes** | code written for an old round |
| 4 | Broken infra references | **yes**, if confirmed | callers of a renamed env var/service/route |
| 5 | Code/config defects | no — warns | logic and infra footguns |

Step 1b blocks nothing — it limits what the later steps can claim.

Step 5 is inline, done by this skill directly reading the diff. No
subagent, and never `/code-review` — that is a billed feature, blocked for
model invocation. This repo is small enough that a fresh-subagent's main
benefit (hiding a huge raw grep/diff dump from your context) doesn't apply
here; reading the diff directly is both simpler and just as thorough at
this scale.

## Prerequisites

- The worktree is on the feature branch of the issue. The PR is open on
  `andrew_wu/homelab`. A draft PR and a ready PR are both correct starting
  points.
- `tea` authenticated (`tea login list` shows a login for
  `git.tailcb6113.ts.net`).
- Run `git fetch origin main` first. Each diff below uses
  `origin/main...HEAD`. A stale local `main` makes the diff too large and
  hides the real change.

## Workflow

### 1. Get the PR and select a mode

```bash
tea pulls <N> -o json -r andrew_wu/homelab
```

Forgejo's draft mechanism is a `WIP:` (or `[WIP]`) title prefix, not a
separate boolean — check the `title` field:

- **Title starts with `WIP:`/`[WIP]` — FLIP mode.** Run gates 2 to 5. Then
  step 6 flips the PR.
- **No `WIP:` prefix — RECHECK mode.** Run gates 2 to 5. Report the result.
  Skip step 6. Never re-add the `WIP:` prefix — a PR that returns to draft
  leaves an open thread with nothing watching it. Report and let the user
  decide.
- **No PR** — stop and tell the user. Do not create a PR.

Take the issue number `N` from the branch name (`feature/<N>-<slug>`). Each
spec gate needs this id.

### 1b. Read the CI results

```bash
tea pulls <N> -f ci -o json -r andrew_wu/homelab
```

Get two things. Neither blocks. Both limit what later steps can claim.

1. **The state of the check.** A red check is a warning, not a block — it
   can be flaky or unrelated to this diff. Give the user the state and let
   them decide.
2. **What CI does not run.** This repo's only workflow is
   `.forgejo/workflows/pr-gate.yml`: `tsc` for `bookmark-webhook` and
   `download-service`, and `docker compose config` for every service. **No
   test suite exists in this repo yet, and CI runs nothing at runtime** — a
   green check means "type-checks and the compose files parse," not "the
   service works." Write one line for the report stating this. Never give a
   green check as evidence that the change actually runs.

Then read the marker:

```bash
GATE_FILE="$(git rev-parse --git-dir)/hl-pr-ready-gate"   # per-worktree, never committed
cat "$GATE_FILE" 2>/dev/null                                # SHA of the last gated commit
git log --oneline <that-sha>..HEAD                          # what landed since
```

If the marker exists and equals `HEAD`, tell the user the gates already ran
on this tree. If it exists and differs, scope steps 4 and 5 to
`<marker>..HEAD`. If no marker exists, scope them to `origin/main...HEAD`.

Write `HEAD` to `$GATE_FILE` after the gates finish — not before. A run
that stops early must not mark the work as checked.

### 2. Gate: is the spec posted? (BLOCKING)

```bash
NOTE="$HOME/personal/project-note/Homelab/2 - Specs/<N>-<slug>.md"
```

See `hl-doc-spec-schema` for this path and its frontmatter fields. Read the
note's frontmatter. Compare:

1. **The round number and the posted rounds.** Compare frontmatter
   `round: N` with the highest `round:` in `posted:`. If `N` is larger,
   unposted rounds exist.
2. **The PR body.** Does it describe the current scope? If a round removed
   an item, does the body still promise it?
3. **The PR title and the issue title.** The title is the last text anyone
   corrects after a scope change.

Verdicts:

- **Unposted rounds exist — block the flip.** Report the gap as
  `round: N, last posted: M`. Name each change between M and N. To correct:
  run `hl-spec-post`, then run `hl-pr-ready` again.
- **A round removed an item, and the title/body still promise it — block
  the flip.** Edit the body; correct the title. This prevents the most
  common self-review miss: "did I actually finish this?"
- **Highest posted round equals current round, and body/title match scope**
  — the gate passes.
- **No spec note exists** — this does not block. Note it and continue (not
  every homelab PR needs the full flow — a one-line fix doesn't need
  `hl-spec-init`).

RECHECK mode cannot block a flip that already happened — this gate blocks
the verdict of the report instead.

### 3. Gate: does the code disagree with the spec? (BLOCKING for drift)

With **2 or more spec rounds**:

```bash
~/bin/hl-spec-round-diff.sh <N>-<slug>
```

Pull the concrete, code-mappable changes from the delta — env var renamed,
port changed, restart policy changed, volume path changed, a
compose-service or Caddy-route name changed. For each, grep the feature
branch for the **old** value:

```bash
grep -rnI "<old-value>" ~/homelab --include='*.yaml' --include='*.yml' --include='*.ts' --include='*.env.example'
```

- Code/config still using the old value → **drift**.
- A removed field/service/route still referenced → **drift**.
- An added item with no code yet → informational, not drift.
- Already matches the new spec → aligned, do not report.

With **exactly 1 round** (no delta to diff), fall back to a *spec-promise
scan*, scoped to the PR's own diff — not the whole repo:

```bash
git diff origin/main...HEAD -- '*.yaml' '*.yml' '.env.example'
```

For each concrete, checkable fact the current spec's Config & secrets /
Data model / Operational concerns / Verification sections state (an env
var, a port, a restart policy, a volume path), check whether the diff
actually delivers it:

- The spec **explicitly** states something the diff **contradicts** (spec
  says `restart: unless-stopped`, diff sets `restart: no` or omits it
  entirely) — **block the flip**, this is a confirmed contradiction, not a
  judgment call.
- The spec states something the diff simply hasn't gotten to yet (PR is
  intentionally partial) — informational, not blocking; note it.
- The spec is silent on something the diff does — not this gate's concern.

**No spec note exists** — this does not block. Note it and continue.

Verdicts:

- **Drift or a confirmed contradiction found — block the flip.** Report
  each, `path:line`, old spec value vs. new. To correct: change the code,
  or re-confirm the spec via `hl-spec-sync`. Then run `hl-pr-ready` again.
- **None found** — the gate passes.

### 4. Gate: search for broken infra references (BLOCKING if confirmed)

A review that only reads the diff cannot find this defect class — the
caller you broke is, by definition, not in the diff. This step is a `grep`,
not a judgment. Run it even for a small diff.

Collect each identifier that appears on a `-` line and on no `+` line:

```bash
git diff origin/main...HEAD | grep '^-' | grep -oE "[A-Z_][A-Z0-9_]*=|^\s*-?\s*[a-z0-9_-]+:"
```

The pattern is a start, not exhaustive. Add by hand: env var names,
compose service/network/volume names, Caddy hostnames/routes, and anything
another service or script (`tmux-build-backend-forgejo.sh`,
`tmux-forgejo-picker.sh`, `README.md`) references by name.

For each identifier, grep the whole repo — not just the app you edited,
the value of this step is in the files the diff doesn't contain:

```bash
grep -rn "<identifier>" ~/homelab
```

Judge each hit:

- **Confirmed.** The hit points at the identifier that was removed or
  renamed, in a file the diff didn't touch.
- **Not confirmed.** Same name, unrelated context. Or the code is dead.

Verdicts:

- **Confirmed — block the flip.** Give `path:line`, the identifier, and the
  replacement name if there is one.
- **Not confirmed — report a warning**, folded into step 5's list.

### 5. Review the diff for defects (WARN-only)

Read the diff directly (scope from step 1b). Do not invoke `/code-review`.
Apply this checklist — a review that only asks "is this correct?" misses
these:

- **Compose service basics.** Does a new service have a `restart:` policy
  consistent with its neighbors? Are secrets read from `.env` rather than
  hardcoded? Is a port published under `ports:` when it should instead stay
  internal-only and reachable via Caddy + a Tailscale node? Does a new
  volume path fall under the repo's `**/data/` gitignore pattern, or will
  it get committed by accident?
- **TypeScript services (`bookmark-webhook`, `download-service`).**
  Unhandled promise rejections on new async calls. Missing error
  handling/retry around a new external HTTP call (this repo has hit this
  class of bug before — see the "add retry" commit history). An env var
  read with no default and no startup validation, so a missing var fails
  silently at request time instead of at boot.
  - **Value that arrives, not the type.** For a new field written to disk
    or sent in a request: what does it actually hold when missing —
    `undefined`, `null`, or `''`? Does downstream code assume one and get
    another?
- **Caddy / Tailscale.** A new node name that collides with an existing
  one. A route added to `caddy/compose.yaml` without its own Tailscale node
  when the repo's pattern is one node per service.
- **New defects inside a correction.** If this diff fixes an earlier
  finding, does the fix leave a second thing without a purpose (a now-dead
  variable, an import that's no longer used)?
- Skip anything a linter or `tsc` already reports — step 1b already covers
  that CI surface.

Report each finding as a warning. Never block on this step — you're the
only reviewer, and you can have a good reason to merge and fix it in a
follow-up. Tell the user they can run `/code-review` themselves for a
deeper (billed) pass — do not run it for them.

### 6. Flip the PR to ready (FLIP mode only)

Do this only if gates 2, 3, and 4 all passed.

```bash
tea pulls edit <N> -r andrew_wu/homelab --ready
```

Report the warnings first, then flip. **Do not merge.** You review the
final diff yourself and merge by hand — that's the deliberate manual
checkpoint in this flow.

Skip this step in RECHECK mode — the PR is already ready.

### 7. Report

- **The mode**: FLIP or RECHECK. If a marker existed, the number of commits
  since the last check.
- **The result**: PR now ready (with URL), or still a draft because a gate
  blocked it, or was already ready and you only checked it.
- **The verdict of each gate**, one by one: passed, blocked, or skipped
  with a reason. A gate that did not run is not a gate that passed.
- **The CI coverage** from step 1b, always — including the "no test suite
  runs" line even when the check is green.
- **The warnings**, as one list: step 5's findings, informational drift
  items, unconfirmed step-4 hits. Write "clean" if empty.

Then write `HEAD` to `$GATE_FILE`.

## Rules

- **Never return a ready PR to draft.** RECHECK mode reports; it never
  changes PR state.
- **Three gates block the flip**: step 2 (spec not posted), step 3
  (confirmed drift/contradiction), step 4 (a confirmed broken reference).
  Each blocks alone.
- Unconfirmed step-4 hits never block. Informational drift never blocks.
- Step 5's findings never block. Report and continue.
- **Never limit the grep in step 4 to the service you edited** — the value
  is in the files the diff doesn't contain.
- A green CI check is not evidence of a test suite that doesn't exist.
  State the gap even when every check is green.
- **Never merge, and never assign reviewers** — there is no CODEOWNERS
  here; the manual merge click is the whole point of stopping at "ready."
- If no PR exists, stop and tell the user. Do not create one.
