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

Turn a Jira ticket into a persistent, versioned spec note that accumulates across
rounds — the single source of truth that reconciles the ticket, chat decisions,
and prototype, so you stop being the human integration layer. The one-shot `/spec`
command reads only the ticket and persists nothing; this writes a real artifact
and grounds it in the actual repos.

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

Delegate to a **general-purpose subagent**, run in the foreground (step 3
depends on its output). Give it: the ticket summary/description from
`manifest.json`, `$MOP_MONOREPO_PATH`, `$MOP_CONFIGURATION_PATH`, and these five
checks to run against the real repos, each cited as `path:line`:

1. **Similar feature already built?** Search `$MOP_MONOREPO_PATH/apps` and
   `/libs` for related pages/components/routes. If found, the spec should reuse or
   align — flag divergences.
2. **Missing details?** Error handling, validation rules, empty/loading/permission
   states, field-level behavior the ticket leaves unstated.
3. **i18n keys already exist?** Extract the candidate UI strings, then per string:
   ```bash
   ~/bin/check-i18n.sh "Submit"          # searches ALL modules by default
   ~/bin/check-i18n.sh "Consol No." tms  # optional: scope to a module + commons
   ```
   Reuse exact/similar matches (output: `EXACT_KEY_MATCH` / `EXACT_VALUE_MATCH` /
   `SIMILAR_MATCHES` / `NO_MATCH`, each with the full `<module>.<key>` path).
4. **Violates existing functionality?** Search for existing behavior the new spec
   would change or break; call it out explicitly.
5. **New privilege needed?** The config repo is **branch-per-environment**
   (`dev`/`uat`/`master`), so a single working-tree grep is misleading — a node
   often exists in `dev` but not yet `uat`/`master`. Check all three:
   ```bash
   git -C "$MOP_CONFIGURATION_PATH" fetch -q origin
   for b in dev uat master; do
     echo -n "$b: "; git -C "$MOP_CONFIGURATION_PATH" show origin/$b:privileges.json | grep -c '<privilege-id>'
   done
   ```
   Report the **promotion state** (e.g. "in dev, missing in uat/master → promote")
   rather than a flat "missing". The v2 `/privilege-node` skill resolves it.

Require the subagent's report to give a finding (or "none found") per check, with
`path:line` evidence only — no raw grep dumps or file contents. **NO GUESSING**
carries into the subagent: unstated stays unstated, never inferred.

### 3. Generate the consolidated spec

Output the spec body in **Traditional Chinese** (team/PM consumption), using:
- `doc-field-table-spec` — frontend field tables
- `doc-api-spec` — API request/response payloads
- `doc-test-scenario` — test scenarios / edge cases

Use only concrete details from the ticket, prototype, and codebase. **Do not
invent** fields, APIs, or behaviors — anything unstated becomes an Open Question,
not a guess.

### 4. Assemble Open Questions (private)

Every gap from step 2 becomes a checkbox with its `path:line` evidence. This list
stays private — you curate it before any of it reaches the PM (that is the v2
`/spec-post` step). Keep questions specific and quotable.

### 5. Write the note, then snapshot

Write `specs/MOP-XXXX.md` using the template below, then:

```bash
~/bin/spec-snapshot.sh MOP-XXXX   # creates round-01
```

Run the snapshot **last**, after the note is written, so `round-01.md` equals the
end-of-round-1 state.

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
- Evidence is `path:line`. A claim about the codebase without a location is a guess.
  This applies to Open Questions and grounding notes — the `規格` body itself never
  contains file paths, component/function/constant names, or route/URLs. It speaks
  in business-level terms only: pages (module + page name), fields, API endpoints.
- Spec body in Traditional Chinese; your status reporting to the user in English.
