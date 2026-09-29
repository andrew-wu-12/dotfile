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
   each item with `· evidence: path:line` where there is evidence.
   - Waiting: `- [ ] <question>  ·  ⏳ 待 PM 回覆 (YYYY-MM-DD)` or
     `⏳ 待後端回覆 (YYYY-MM-DD)`. The date is when it was first deferred.
   - Never asked (headless run, or a note from before the marker existed):
     `- [ ] <question>` with no `⏳`.
   - Answered: `- [x] <question>  ·  → **<answer>**（<source>, YYYY-MM-DD）`.
4. `## Decision Log` — `| Date | Source | Decision |` table, append-only.
   - Headers and `Source` tags (`jira`/`chat`/`dev`/`pm`) stay in English.
   - The Decision text is in Traditional Chinese.
   - spec-sync rows start with a change reason in brackets: `〔PM 規格變動〕`,
     `〔Dev 理解錯誤〕`, `〔先前決議錯誤〕`, `〔新資訊〕`, or free text. A row that
     replaces an earlier decision ends with `，取代 YYYY-MM-DD「…」`.
5. `## Round History` — `- **Round N** (date): summary`, append-only.
   - The `**Round N** (date):` label stays in English. The summary is in
     Traditional Chinese.
   - spec-sync entries end with a count per reason, e.g.
     `（2 項 PM 規格變動、1 項新資訊）`.

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
- [ ] <question>  ·  evidence: `path:line`  ·  ⏳ 待 PM 回覆 (<YYYY-MM-DD>)

## Decision Log
| Date | Source | Decision |
|------|--------|----------|
| <YYYY-MM-DD> | jira | 依 Jira ticket 與 prototype 建立初版規格。 |

## Round History
- **Round 1** (<YYYY-MM-DD>): 依 Jira ticket 與 prototype 建立初版規格。
```
