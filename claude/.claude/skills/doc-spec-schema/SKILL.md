---
name: doc-spec-schema
description: >-
  Shared artifact schema for the spec note: file path, frontmatter fields,
  and section headings. Used by spec-init (creates the note), spec-post and
  pr-ready (read frontmatter fields) — not meant to be invoked on its own.
---

# Doc Spec Schema → shape of the spec artifact

The shared structural facts about the spec note — where it lives, what its
frontmatter fields mean, and what sections it has — regardless of which
skill is creating, reading, or updating it. `spec-init`, `spec-post`, and
`pr-ready` all reference this instead of restating it.

## Artifact location

- Note: `~/personal/office-note/Specs/MOP-XXXX.md`
- Round snapshots: `.../Specs/.rounds/MOP-XXXX/round-NN.md` (machine-diffable;
  the vault auto-commits every ~65s so git history is not a round boundary —
  these files are).

## Frontmatter fields

- `tags` — vault tags, always includes `📥/🟧` and `spec`.
- `ticket` — the Jira id, e.g. `MOP-XXXX`.
- `created` — `YYYY-MM-DD`, set once at spec-init.
- `round` — current round number. Bumped by spec-sync each round.
- `prototype` — Figma/prototype URL, or empty.
- `posted` — list of publish records, one per spec-post write. Each entry:
  `{round, date, url?, description}`. `url` is the comment URL when a
  comment was posted; omitted for a description-only re-sync. `description`
  is `synced` or `resynced`. Shape only — see `spec-post` for how the
  baseline round is chosen and when to write which value.

## Sections (in order)

1. `# [MOP-XXXX] <summary>` — title, plus `> Jira:` link line.
2. `## 規格 (Consolidated Spec)` — see `doc-spec-body` for what this contains.
3. `## Open Questions (private — curate before /spec-post)` — checkbox list,
   each item with `· evidence: path:line`.
4. `## Decision Log` — `| Date | Source | Decision |` table, append-only.
5. `## Round History` — `- **Round N** (date): summary`, append-only.

## Template

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
- API 端點（Request/Response JSON，`[MISSING]` 標示未知值）

### 3. 測試案例情境
- 邊界案例（Precondition/Action/Expected Result）

## Open Questions (private — curate before /spec-post)
- [ ] <question>  ·  evidence: `path:line`

## Decision Log
| Date | Source | Decision |
|------|--------|----------|
| <YYYY-MM-DD> | jira | Initial spec captured from ticket + prototype. |

## Round History
- **Round 1** (<YYYY-MM-DD>): initial spec from Jira ticket and prototype.
```
