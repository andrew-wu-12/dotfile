---
name: mop-spec-document
description: >-
  Fold a shipped ticket into the MOP frontend feature notes (`Docs/**` in the
  office-note vault): locate the ticket's merged code in `main`, map it to the
  notes it touches, report what is new, changed, stale, or in conflict with
  the spec, then apply on approval. Use after a prod merge, when a finished
  ticket's docs need updating, "mop-spec-document MOP-XXXX", or
  "mop-spec-document uat/MOP-XXXX" for a whole release. Last step of the
  mop-spec-* flow.
---

# Spec Document → fold a shipped ticket into Docs

The `Docs/**` feature notes describe shipped behaviour. Every ticket that
reaches `main` moves that behaviour, and this skill moves the notes with it.

`mop-frontend-document` owns the note: format, callout vocabulary, writing
style, headings-as-API, the vault link check, and knock-on edits. Read
`~/.claude/skills/mop-frontend-document/SKILL.md` at step 4 and apply every
rule in it. This skill owns only the scoping — which code shipped, which
notes it lands in, and which findings to raise.

The spec note `Specs/MOP-XXXX.md` is read-only input here.

## Inputs

- `MOP-XXXX` → **ticket mode**. `uat/MOP-XXXX` → **release mode**: every
  feature/hotfix ticket that shipped with that uat branch.
- Monorepo: `$MOP_MONOREPO_PATH`. Vault: `~/personal/office-note`.

## 1. Locate the shipped merges

```bash
git -C "$MOP_MONOREPO_PATH" fetch -q origin
```

**Ticket mode** — the ticket's merge commits that `main` contains:

```bash
git -C "$MOP_MONOREPO_PATH" log origin/main --merges -E \
  --grep='from [^ ]+/(feature|hotfix)/MOP-XXXX($|[^0-9])' --pretty='%h %s'
```

Suffixed branches (`feature/MOP-XXXX-1`, `feature/MOP-XXXX-dev-shared-libs`)
belong to the ticket. `-merge-main-` branches carry `main`, not ticket work —
drop them.

**Release mode** — the `[PROD]` merge `P`, then the tickets between its
parents:

```bash
P=$(git -C "$MOP_MONOREPO_PATH" log origin/main --first-parent --merges -E \
  --grep='from [^ ]+/uat/MOP-XXXX$' -1 --pretty=%H)
git -C "$MOP_MONOREPO_PATH" log --merges --pretty='%h %s' "$P^1..$P^2"
```

Keep the `feature|hotfix/MOP-\d+` merges (same suffix and `-merge-main-`
rules), grouped by ticket id.

**Not in `main`** (no match, or no `P`): look for the merges under
`origin/uat/*` instead (release mode: `origin/main..origin/uat/MOP-XXXX`).
Report where they are and ask whether to document that uat branch. On yes,
it becomes the **baseline** for the rest of the run, and the report header
says so. Found nowhere → stop: the PR was squash-merged or never merged; ask
the user for a commit range.

Done when every ticket has at least one merge commit and the baseline ref
(`origin/main` or the agreed uat branch) is named.

## 2. Collect the changed surface

For each merge `M`, diff its first parent against it:

```bash
git -C "$MOP_MONOREPO_PATH" diff --stat "$M^1" "$M"
git -C "$MOP_MONOREPO_PATH" diff "$M^1" "$M" -- <paths>
```

`M^1 → M` is what that merge brought into its target, so `main` merged into
the feature branch earlier drops out. Union the paths per ticket. Paths under
`apps/` and `libs/` are the surface; tests, stories, and config files serve
only as evidence.

The diff says **which** code changed. What the code does **now** comes from
the baseline — a later ticket may have moved it again:

```bash
git -C "$MOP_MONOREPO_PATH" show <baseline>:<path>
```

Read through `git show` only; leave every checkout and worktree as it is.

## 3. Map paths to notes

```bash
grep -rn '^\*程式碼位置' ~/personal/office-note/Docs --include=*.md
```

A path belongs to the note whose code location contains it; the longest
prefix wins. Unmatched paths:

- A new feature directory under `apps/` (a new page or module) → propose a
  new note at `Docs/<area>/<Feature>.md`, the area taken from sibling notes
  (`apps/tms` → `Docs/M1 TMS/`). The path is confirmed in the report.
- `libs/`, shared utilities, and small leftovers → the **skipped** list.
  `libs/` changes are `doc-common-component-changelog`'s job.

Done when every path from step 2 sits under a note, a proposed note, or the
skipped list.

## 4. Audit each note

Read `~/.claude/skills/mop-frontend-document/SKILL.md` now.

Read `~/personal/office-note/Specs/MOP-XXXX.md` for each ticket: `規格` gives
the business terms, the `Decision Log` gives the reason behind a rule. No
spec note → work from the code alone and say so in the report.

For each mapped note, read the note and the changed code (in the dependency
order `mop-frontend-document` gives) and sort every behaviour change into:

- **新增** — behaviour the note never covered.
- **修改** — the note covers it, and is now wrong.
- **已過時** — the note covers something the ticket removed.
- **Conflict** — the spec says one thing, the code does another. The note
  follows the code. The finding carries both anchors (`Specs/MOP-XXXX.md`
  section ↔ `file:line`) so the user can judge which side is wrong.

Each finding is anchored to `file:line` at the baseline and names the note
heading it lands under.

Done when every changed path from step 2 is accounted for by a finding, an
explicit "no user-visible change" line, or the skipped list.

## 5. Report and wait

```markdown
## mop-spec-document — <MOP-XXXX | uat/MOP-XXXX>
Baseline: origin/main @ <sha>  ·  Tickets: MOP-A (#PR, #PR), MOP-B (#PR)

### Docs/M1 TMS/<Note>.md
- 新增 · <heading> · <finding> · `path:line` · MOP-A
- 修改 · <heading> · <now wrong: … → …> · `path:line` · MOP-B
- 已過時 · <heading> · <removed behaviour> · `path:line` · MOP-A

### New note proposed
- `Docs/<area>/<Feature>.md` ← `apps/<app>/.../<Feature>/` · MOP-A

### Conflicts (spec ↔ code)
- MOP-A · 規格 <section>: <spec claim> ↔ `path:line`: <code behaviour>

### Skipped
- `libs/...` · MOP-B · common component → doc-common-component-changelog

### Suspected code defects
- …
```

Release mode groups by note; the ticket tag on each finding keeps the
origin visible. Stop here. One approval covers the run; the user may veto or
correct individual findings.

## 6. Apply

Edit the approved findings into the notes under `mop-frontend-document`'s
rules, including its link check and knock-on edits. Proposed new notes use
its note structure.

Ticket attribution: `（MOP-XXXX）` marks a rule or special case a reader would
ask "why" about, in a callout sub-title or table row
(`驗證規則 — Dummy Carrier（MOP-29278）`). Ordinary behaviour carries no
ticket tag.

The vault auto-commits; leave git alone.

Done when every approved finding is in a note, the link check passes, and
knock-on edits are listed in the closing message.

## Reruns

The skill keeps no state. A rerun re-audits, and behaviour already in the
notes produces no finding.
