# Profile: mop

MOP frontend tickets on Jira. Spec notes live in the `office-note` Obsidian
vault.

## Identity and paths

- ID: Jira key, `MOP-XXXX`. `<id>` == the key.
- Branch: `feature/MOP-XXXX`.
- `SPECS` = `$HOME/personal/office-note/Specs`.
- Vault commits: none. Obsidian Git auto-commits the vault every ~65s, so
  never `git commit` a spec note.

## Note language

- Note language: Traditional Chinese (spec body, Decision Log text, Round
  History summaries, Open Questions).
- Reports to the user: English.

## Frontmatter (in addition to schema.md's)

- `tags` — always includes `📥/🟧` and `spec`.
- `ticket` — the Jira key.
- `prototype` — Figma/prototype URL, or empty.

## Decision Log and Open Questions

- Source tags: `jira`, `chat`, `pm`, `dev`.
- Waiting buckets: `待 PM 回覆`, `待後端回覆`.
- Change reasons: `〔PM 規格變動〕`, `〔Dev 理解錯誤〕`, `〔先前決議錯誤〕`,
  `〔新資訊〕`.
- Replaces suffix: `，取代 YYYY-MM-DD「…」`.
- Round History reason count, e.g. `（2 項 PM 規格變動、1 項新資訊）`.

## Spec body

Heading: `## 規格 (Consolidated Spec)`.

### Formats

- **Frontend fields** — `doc-field-table-spec`'s table format.
- **API payloads** — a Request/Response JSON example per endpoint, not a
  description.
- **Test scenarios** — one Precondition/Action/Expected-Result block per
  scenario: the main flow plus its edge and negative cases.

### Terms

- **Show**: pages (`{module_name} - {page_name}`), data fields, i18n keys,
  API endpoints.
- **Avoid**: file paths, component names, function names, hook names,
  routes, URLs, code constants.

### Prose style — 使用者操作 / 視圖邏輯

- **One state per top-level bullet, parallel across the whole doc.** When
  behavior branches on a state (e.g. record/dispatch status), give each
  state its own top-level bullet, phrased the same way every time it recurs
  (across 使用者操作, 視圖邏輯, and 測試案例情境). Do not bury a state
  condition inside a clause of another bullet.
- **Only new or changed behavior gets a bullet.** Omit restatements of
  unchanged behavior, e.g. `此功能沿用現有 X privilege，不變` or
  `Y 沿用現有流程，本張 ticket 不新增規格`.
- Asides like `(現有行為)`, `(不新增文案)`, `(沿用現有 XXX 流程)` are
  justification asides — drop them (`body.md`).

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

## Open Questions (private — curate before spec-post)
- [ ] <question>  ·  evidence: `path:line`  ·  ⏳ 待 PM 回覆 (<YYYY-MM-DD>)

## Decision Log
| Date | Source | Decision |
|------|--------|----------|
| <YYYY-MM-DD> | jira | 依 Jira ticket 與 prototype 建立初版規格。 |

## Round History
- **Round 1** (<YYYY-MM-DD>): 依 Jira ticket 與 prototype 建立初版規格。
```
