# Profile: mop

MOP frontend tickets on Jira. Spec notes live in the `office-note` Obsidian
vault.

## Identity and paths

- ID: Jira key, `MOP-XXXX`. `<id>` == the key.
- Branch: `feature/MOP-XXXX`.
- `SPECS` = `$HOME/personal/office-note/Specs`.
- Vault commits: none. Obsidian Git auto-commits the vault every ~65s, so
  never `git commit` a spec note.

## Tracker

- Channels: the Jira ticket, chat/verbal discussion with the PM, and the
  prototype (Jira image attachments).
- Access: Jira token in the credential store (scripts read it via
  `~/bin/cred-read.sh`).
- Fetch: **delegated**. Run a fresh subagent in the foreground using
  `tool-ticket-get`. Give it the ticket ID and the note's last Round History
  date. Require its report to list new comments verbatim and the file paths
  of new attachments, not descriptions of them.
- Init extras: note every Figma/prototype URL in the description or
  comments; the first goes in frontmatter `prototype`.

## Grounding

- Repos: `$MOP_MONOREPO_PATH`, `$MOP_CONFIGURATION_PATH`.
- Run: **delegated**, a fresh subagent in the foreground.
- Checks:
  1. **Similar feature already built?** Search `$MOP_MONOREPO_PATH/apps` and
     `/libs` for related pages, components, routes. If one exists, the spec
     reuses it or aligns with it. Flag any divergence.
  2. **Missing details?** Error handling, validation rules,
     empty/loading/permission states, and field-level behavior the ticket
     leaves unstated.
  3. **i18n keys already exist?** Extract the candidate UI strings, then
     check them all in one call:
     ```bash
     ~/bin/check-i18n.sh --batch <<< $'Submit\nConsol No.'          # all modules
     ~/bin/check-i18n.sh --batch tms <<< $'Submit\nConsol No.'      # one module + commons
     ```
     Reuse exact/similar matches (output per string: `EXACT_KEY_MATCH` /
     `EXACT_VALUE_MATCH` / `SIMILAR_MATCHES` / `NO_MATCH`, each with the full
     `<module>.<key>` path).
  4. **Violates existing functionality?** Existing behavior the new spec
     would change or break.
  5. **New privilege needed?** The config repo has one branch per
     environment, and a node often exists in `dev` but not yet in `uat` or
     `master`. Check all three:
     ```bash
     git -C "$MOP_CONFIGURATION_PATH" fetch -q origin
     for b in dev uat master; do
       echo -n "$b: "; git -C "$MOP_CONFIGURATION_PATH" show origin/$b:privileges.json | grep -c '<privilege-id>'
     done
     ```
     Report the **promotion state** (e.g. "in dev, missing in uat/master →
     promote"), not a flat "missing". `mop-check-privilege` resolves it.

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
- Recommended reason by source: `jira`/`pm` → `PM 規格變動`; `chat` from a
  dev → `新資訊`.
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
