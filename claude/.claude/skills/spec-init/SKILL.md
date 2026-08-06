---
name: spec-init
description: >-
  Create a persistent, codebase-grounded spec artifact for a Jira ticket in the
  Obsidian vault, plus a private Open-Questions list. Use when starting a new
  ticket, initializing a spec, opening the spec for MOP-XXXX, or "spec-init
  MOP-XXXX". Replaces the one-shot /spec for real ticket work; use spec-sync for
  later rounds.
---

# Spec Init → durable spec artifact

Turn a Jira ticket into a persistent, versioned spec note. The note accumulates
across rounds. It reconciles the ticket, chat decisions, and the prototype into
one source of truth, so you stop acting as the manual integration layer. The
one-shot `/spec` command reads only the ticket and saves nothing. This skill
writes a real artifact and grounds it in the actual repositories.

`SKILL_DIR` = `~/.claude/skills/spec-init`.

## Artifact location

- Note: `~/personal/office-note/Specs/MOP-XXXX.md`
- Round snapshots: `.../Specs/.rounds/MOP-XXXX/round-NN.md` (machine-diffable;
  the vault auto-commits every ~65s so git history is not a round boundary — these
  files are).

## Prerequisites

- **`JIRA_TOKEN`** (`source ~/.zshrc`). The fetch returns a clean error if the token is wrong.
- Repos on disk: `$MOP_MONOREPO_PATH`, `$MOP_CONFIGURATION_PATH`.
- If `specs/MOP-XXXX.md` **already exists**, stop — this is a later round. Tell the
  user to run `spec-sync` instead.

## Workflow

### 1. Fetch the ticket

```bash
OUT=$(mktemp -d)
~/bin/fetch-ticket.sh MOP-XXXX "$OUT" > "$OUT/manifest.json"
```

Read `manifest.json` (summary, type, parent, description, comments, attachments).
**Read every image in `.attachments[].path`** — these are the prototype
screenshots and are part of the spec. Note any Figma/prototype URLs found in the
description or comments; record them in the note header.

### 2. Ground in the codebase — the five checks (delegated)

Delegate this to a **general-purpose subagent**. Run it in the foreground —
step 3 needs its output first. Give the subagent:
- the ticket summary and description from `manifest.json`
- `$MOP_MONOREPO_PATH`
- `$MOP_CONFIGURATION_PATH`
- these five checks to run against the real repos, each cited as `path:line`

1. **Similar feature already built?** Search `$MOP_MONOREPO_PATH/apps` and
   `/libs` for related pages/components/routes. If one exists, the spec should
   reuse it or align with it. Flag any divergence.
2. **Missing details?** Check for error handling, validation rules,
   empty/loading/permission states, and field-level behavior the ticket leaves
   unstated.
3. **i18n keys already exist?** Extract the candidate UI strings, then per string:
   ```bash
   ~/bin/check-i18n.sh "Submit"          # searches ALL modules by default
   ~/bin/check-i18n.sh "Consol No." tms  # optional: scope to a module + commons
   ```
   Reuse exact/similar matches (output: `EXACT_KEY_MATCH` / `EXACT_VALUE_MATCH` /
   `SIMILAR_MATCHES` / `NO_MATCH`, each with the full `<module>.<key>` path).
4. **Violates existing functionality?** Search for existing behavior the new spec
   would change or break; call it out explicitly.
5. **New privilege needed?** The config repo uses one branch per environment
   (`dev`/`uat`/`master`). A single working-tree grep can mislead: a node often
   exists in `dev` but not yet in `uat` or `master`. Check all three branches:
   ```bash
   git -C "$MOP_CONFIGURATION_PATH" fetch -q origin
   for b in dev uat master; do
     echo -n "$b: "; git -C "$MOP_CONFIGURATION_PATH" show origin/$b:privileges.json | grep -c '<privilege-id>'
   done
   ```
   Report the **promotion state** (e.g. "in dev, missing in uat/master → promote")
   rather than a flat "missing". The v2 `/privilege-node` skill resolves it.

Require the subagent's report to give one finding per check, or state "none
found." Support each finding with `path:line` evidence only — no raw grep dumps
or file contents. **NO GUESSING** applies to the subagent too: if the ticket
does not state something, record it as unstated. Never infer it.

### 3. Generate the consolidated spec

Output the spec body in **Traditional Chinese** (team/PM consumption), using:
- `doc-field-table-spec` — frontend field tables
- `doc-api-spec` — API request/response payloads
- `doc-test-scenario` — test scenarios / edge cases

Use only concrete details from the ticket, the prototype, and the codebase. **Do
not invent** fields, APIs, or behaviors. If the ticket does not state something,
add it to Open Questions instead of guessing.

### 4. Assemble Open Questions (private)

Every gap from step 2 becomes a checkbox with its `path:line` evidence. This
list stays private. You curate it before it reaches the PM — that happens in
the `/spec-post` step. Keep each question specific and quotable.

### 5. Write the note, then snapshot

Write `specs/MOP-XXXX.md` using the template below, then:

```bash
~/bin/spec-snapshot.sh MOP-XXXX   # creates round-01
```

Run the snapshot **last**. Run it only after you write the note, so
`round-01.md` matches the end-of-round-1 state.

### 6. Report

List the following in English:
- Open Questions list
- Cross-source conflicts

## Note template

```markdown
---
tags:
  - 📥/🟧
  - spec
ticket: MOP-XXXX
created: <YYYY-MM-DD>
round: 1
prototype: <figma-url or empty>
---
# [MOP-XXXX] <summary>

> Jira: https://morrisonexpress.atlassian.net/browse/MOP-XXXX

## 規格 (Consolidated Spec)

### 1. 前端規格
- **頁面/視圖：** …
  - 欄位規格：（doc-field-table-spec）
- **使用者操作：** …
- **視圖邏輯：** 載入、錯誤、邊界、權限狀態

### 2. 後端規格
- API 端點（doc-api-spec）

### 3. 測試案例情境
- 邊界案例（doc-test-scenario）

## Open Questions (private — curate before /spec-post)
- [ ] <question>  ·  evidence: `path:line`

## Decision Log
| Date | Source | Decision |
|------|--------|----------|
| <YYYY-MM-DD> | jira | Initial spec captured from ticket + prototype. |

## Round History
- **Round 1** (<YYYY-MM-DD>): initial spec from Jira ticket and prototype.
```

## Rules

- NO GUESSING. Unstated → Open Question.
- Evidence means `path:line`. A codebase claim without a location is a guess.
  This rule covers Open Questions and grounding notes. The `規格` body never
  contains file paths, component names, function names, constant names, or
  route URLs. It uses business-level terms only: pages (module + page name),
  fields, and API endpoints.
- Write the spec body in Traditional Chinese. Report status to the user in English.
