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
- You: your Jira account. A comment is yours when its author matches your
  `displayName`:
  ```bash
  curl -s -u "$(~/bin/cred-read.sh morrisonexpress.atlassian.net)" \
    https://morrisonexpress.atlassian.net/rest/api/2/myself | jq '{displayName, accountId}'
  ```
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

### Challenge cross-references

- A field named in an API request/response example but missing from the
  field table, or the reverse.

## Post

- Body heading match (for `awk -v h=`): `## 規格`.
- Scripts: `~/bin/md2jira.sh`, `~/bin/jira-comment.sh`,
  `~/bin/jira-description.sh`.
- Fetch and guards: **delegated**. A fresh subagent in the foreground uses
  `tool-ticket-get` (note the temp dir it creates as `$OUT`), then fetches
  the raw description:
  ```bash
  ~/bin/jira-description.sh get MOP-XXXX > "$OUT/description.live"
  ```
  The manifest's description is HTML-stripped plain text, fine for reading
  comments but too lossy to archive or ownership-check. `description.live` is
  raw wiki markup. Jira round-trips wiki markup through ADF, so formatting
  shifts on every write — match the stamp token, never the panel shape.
- Own-author comments: yours (Tracker "You"). Header to match:
  `Round N` + `規格確認`. The posted source has escaped brackets
  (`\[Round 5\]`); the manifest holds the rendered text.
- Archive foreign description (main thread, after approval):
  ```bash
  { echo "h3. 原 description 備份（spec-post 覆寫前，$(date +%F)）"; echo "{quote}";
    cat "$OUT/description.live"; echo "{quote}"; } > "$OUT/archive.wiki"
  ~/bin/jira-comment.sh MOP-XXXX "$OUT/archive.wiki"
  ```
- Postable questions: unchecked items marked `⏳ 待 PM 回覆` only.
  `⏳ 待後端回覆` items stay private — the backend is asked directly, not
  through the PM's comment. An unchecked item with no `⏳` was never asked:
  list those separately, suggest `spec-sync` first, and do not post them.
- Stamp phrase (guard 1): `本規格由 spec-post 自動同步`.
- Description: Jira wiki markup in `$DRAFTS/description.wiki`. **Do not
  demote headings** — the panel acts as the header, so `## 規格` maps to
  `h2.`. The panel is already wiki markup; do not run it through
  `md2jira.sh`:
  ```bash
  cat > "$DRAFTS/description.wiki" <<EOF
  {panel:title=Round N · 最後更新 $(date +%F)}
  本規格由 spec-post 自動同步，每輪覆寫。
  變更紀錄請見留言。
  {panel}

  EOF
  ~/bin/md2jira.sh < "$DRAFTS/spec.md" >> "$DRAFTS/description.wiki"
  ```
  Warn above ~30,000 characters (`wc -m`): Jira's limit is 32,767, and
  `jira-description.sh set` refuses anything past it.
- Comment: write `$DRAFTS/comment.md`, then
  `~/bin/md2jira.sh < "$DRAFTS/comment.md" > "$DRAFTS/comment.wiki"`:
  1. `[~accountid:<id>]` (omit the line if no mention)
  2. `## [Round N] 規格確認`
  3. `### 需要確認` — the curated questions, numbered
- Mention: **always ask, never auto-resolve.** Offer the real candidates by
  display name: the ticket reporter, the parent ticket's reporter (often the
  PM when the user filed the sub-ticket), recent commenters, or no mention.
  ```bash
  curl -s -u "$(~/bin/cred-read.sh morrisonexpress.atlassian.net)" -H "Content-Type: application/json" \
    "https://morrisonexpress.atlassian.net/rest/api/2/issue/MOP-XXXX?fields=reporter,parent" \
    | jq '{reporter: .fields.reporter | {displayName, accountId}, parent: .fields.parent.key}'
  ```
- Writes:
  ```bash
  ~/bin/jira-description.sh set MOP-XXXX "$DRAFTS/description.wiki"   # prints browse URL
  ~/bin/jira-comment.sh      MOP-XXXX "$DRAFTS/comment.wiki"          # prints comment URL
  ```

## Drift

- Code repo: `$MOP_MONOREPO_PATH`, on `feature/MOP-XXXX`.
- Round-diff path (steps 2–4): **delegated** to a fresh subagent.
- Change kinds:
  - field **id / name** changed or renamed (e.g. `console_number_list` → `consol_number_list`)
  - field **type** changed (e.g. text → multi-select)
  - optional ↔ **required** flip, or a validation rule added/changed
  - **API endpoint** path / method / payload key changed
  - **i18n key** changed
  - result **column** added / removed / renamed
  - **privilege** id changed
- Search command (scope to the ticket's app/module):
  ```bash
  grep -rnIF -f "$VALUES" "$MOP_MONOREPO_PATH/apps/<app>" \
    --include='*.ts' --include='*.tsx' --include='*.vue'
  ```
- One-round scan: **cardinality ambiguity**. It hunts code that silently
  assumes a 1:1 relationship the spec never confirmed — or that the spec
  states is 1:N.
  ```bash
  git -C "$MOP_MONOREPO_PATH" diff <base>...HEAD -- 'apps/<app>/**/*.ts' 'apps/<app>/**/*.tsx'
  ```
  `<base>` is the Flow section's `<base>` — a feature branch off
  `uat/<parent>` must not be diffed against `main`, or every other ticket in
  the epic lands in the diff.
  1. In the diff, find single-record lookups: `.find(...)` on an array, or a
     function typed to return `T | undefined` / a bare `T` (not `T[]`),
     where the lookup key is identifier-shaped (`*_id`, `*_no`, `*_number`,
     `*Id`, `*Number`, …) and the result is a multi-field domain object (skip
     type-guard/enum lookups).
  2. For each, name the **key field** and the **target entity**.
  3. Grep the current spec round for both concepts together:
     - spec confirms 1:1 (`唯一`, `unique`, `一個…對應一個`) → aligned, do
       not report;
     - spec states or implies 1:N (`多筆`, `多個`, `list`, `multiple`) and
       the code does a singular lookup → **Contradiction**;
     - spec silent on cardinality → **Soft finding** (ambiguity): "worth
       confirming: can `<key>` map to more than one `<target>`?" Most
       unstated cardinality is fine; this is a nudge, not an accusation.
- One-round Contradiction blocks the flip: **no** — report it, the user
  decides.

## Ready

- PR CLI: `gh` (authenticated). VPN and the Jira token give the spec gates
  their data.
- PR view: `gh pr view --json number,isDraft,title,url,headRefName,body`.
  Draft signal: `isDraft`.
- CI and comments:
  ```bash
  gh pr checks <number>
  gh pr view <number> --json comments,reviews
  ```
- What CI does not run (last confirmed): PR CI runs unit tests
  (`nx affected -t test`, `continuous_integration.yml`) and builds
  (`nx affected -t build`, `knip_pr_build.yml`). **No Cypress e2e** — no
  workflow under `.github/` refers to Cypress. The e2e job is
  `.jenkins/e2e_testing/jenkinsfile`, checks out `branch: 'main'`, and is
  gated by `E2E_TESTING_TAG`. A diff can break an e2e test with every check
  green.
- Reviewers: **yes** — build the review-comment index.
- Bot requests: the shared-component doc check needs a Confluence link in
  the References block of the PR description for each `libs/**` change. Its
  GitHub check reports `pass` while its comment reports the link absent. If
  absent, warn and name `/doc-common-component-changelog`.

### Extra gate 3b: browser run of the test scenarios (BLOCKING for a current FAIL)

`mop-spec-verify` runs the scenarios of `### 3. 測試案例情境` in a browser
and writes one row per scenario to a record. This gate only reads the
record. **Never start the browser run from here** — it is slow and needs a
running app.

```bash
RESULT="$WORKTREE_ROOT/mop-console-monorepo/MOP-XXXX.verify.json"
git rev-parse HEAD
```

Number the scenarios in `### 3. 測試案例情境` 1, 2, 3, … in order. A row is
**current** if its `sha` equals `HEAD` and its `round` equals the note's
`round`; otherwise **stale**.

- **A current row is FAIL — block.** Report the scenario number, expected
  text, actual text, and screenshot path. Fix the code or re-confirm the
  spec, then `/mop-spec-verify MOP-XXXX <n>` and `spec-ready` again.
- **Every scenario has a current PASS row** — passes.
- **Otherwise** — one warning naming the scenarios with no row, a stale row,
  or an INCONCLUSIVE row (with its reason), and the command to fix it:
  `/mop-spec-verify MOP-XXXX <n> <n>`, or `/mop-spec-verify MOP-XXXX` with no
  record.
- **No spec note, or no scenario** — does not block.

A stale FAIL does not block: the code or the spec changed after the run.

### Gate 4: identifiers

- Pattern:
  ```bash
  git diff origin/main...HEAD | grep '^-' | grep -oE "(id|name|data-testid)='[^']+'|#[a-zA-Z_][a-zA-Z0-9_.-]*"
  ```
- By hand: exported symbols, i18n keys, API field names, CSS tokens,
  `classNamePrefix` tokens, `localStorage` keys, privilege ids.
- Search: **delegated** to a fresh subagent — a repo-wide grep for a field
  name hits every unrelated module (one real run: 10 hits, 2 defects). Give
  it the identifier list, the old → new mapping for each rename, each newly
  added selector token, and both checks; it returns one verdict per
  identifier/selector, `path:line` only:
  1. **Removed/renamed identifiers.** For each:
     ```bash
     ~/bin/identifier-scope-check.sh '<identifier>' "$MOP_MONOREPO_PATH"
     ```
     Pass only the bare identifier (`foo`, not `id='foo'`), and only if it
     matches `^[A-Za-z0-9_.:#/-]+$`. Anything else never goes on the command
     line: search it with `grep -rnIF -f <file>` and bucket the hits by
     hand.
     It buckets every hit into out-of-scope (auto-dismissed) and in-scope
     (with context). An app-local diff is bucketed by directory prefix (plus
     the matching `-e2e` dir); a `libs/` change traces which files import
     the lib's resolved alias, since shared libs have cross-app callers.
     Judge only the in-scope hits; trust its out-of-scope bucketing. The
     same name in a different feature is a different field. Never change a
     hit before tracing it to the renamed identifier.
  2. **Selectors that now match two elements.** No removal needed — an
     added element is enough. For each new selector token (a shared
     `classNamePrefix`, a CSS class, a `data-testid` pattern), count matches
     before and after. If 1 becomes 2+, check each call site: a bare
     `.click()`, `.type()`, or `.should('have.value')` expects one element;
     `.first()`, `.eq()`, and `within()` set a scope. An unscoped call site
     is now broken — **Confirmed**.

### Step 5: review

- Run: **delegated** to a fresh subagent with the scoped diff.
- Checklist:
  - **Effect re-invocation.** React StrictMode runs mount → cleanup → mount
    in development. For each new or changed `useEffect`: does setup
    re-initialize every value cleanup removed (refs, flags)? Can a value
    keep first-cleanup state into the second mount?
  - **Components running at the same time.** Does the diff change a
    component that runs alongside another that shares state? (A modal opens
    while a loop or listener in a second component keeps running below it.)
    Read one level past the changed files if needed.
  - **The value that arrives, not the type.** For each new or changed
    validator, schema, or type guard:
    1. Find the value the field holds at run time; do not trust the type.
    2. Follow it from the API to the form through every layer that changes
       it.
    3. `convertNullToString` (`libs/shared/util/buildable-utils`) turns every
       API `null` into `''`, at every depth — so `''` is the empty value,
       not `null` or `undefined`.
    4. A non-string schema is therefore wrong unless it first transforms
       `''`: `Yup.number()`, `Yup.date()`, `Yup.array()`. `.nullable()` does
       not fix it; `Yup.number()` casts `''` to `NaN` and fails the type
       check.
    5. List three cases for the field: empty, `null`, absent.
    6. If the submit button depends on the schema, the form stays invalid
       with no way forward — worse than one field message.
    7. Grep two signals: nearby code already testing `=== ''` on this field
       (someone hit this before), and the English yup type error showing
       instead of the i18n message (the cast failed, not your rule).
  - **New defects inside a correction.** If the diff fixes an earlier
    finding, does the fix leave something without a purpose? Read what the
    correction changed; do not only confirm the first defect is gone.

### Flip

```bash
gh pr ready <number>
```

Merge rule: CODEOWNERS requests the owners of owned paths; the user assigns
any other reviewers and merges.

## Flow

- Branch: the worktree from `mwt` for the ticket
  (`$WORKTREE_ROOT/mop-console-monorepo/MOP-XXXX`), or `$MOP_MONOREPO_PATH`
  on `feature/MOP-XXXX`.
- `<base>`: the PR's base (`gh pr view --json baseRefName`, as
  `origin/<baseRefName>`). With no PR, `origin/main`.
- Commit count: `mwt` seeds every branch with an empty
  `Initial draft for branch …` commit, which is not implementation. Skip it:
  ```bash
  git rev-list --count --invert-grep --grep='^Initial draft for branch' <base>..HEAD
  ```
- PR lookup: `gh pr view --json number,isDraft,state` on the feature branch.
  No PR → none; `OPEN` + `isDraft` → draft; `OPEN` → ready; `MERGED` →
  merged; `CLOSED` → closed.
- Pre-ready steps (row 10): `mop-spec-verify MOP-XXXX`, only when the verify
  record (`$WORKTREE_ROOT/mop-console-monorepo/MOP-XXXX.verify.json`) lacks a
  current PASS row (`sha` == `HEAD`, `round` == note round) for some
  scenario. It drives the single global `yarn serve`; it restores the
  previous serve target itself.
- Shipped check:
  ```bash
  git -C "$MOP_MONOREPO_PATH" fetch -q origin
  git -C "$MOP_MONOREPO_PATH" log origin/main --merges -E -1 \
    --grep='from [^ ]+/(feature|hotfix)/MOP-XXXX($|[^0-9])' --pretty='%h %s'
  ```
  Any output → shipped.
- Shipped action: ask whether to run `mop-spec-document MOP-XXXX` (it may
  have run already — nothing records that). Then the ticket is done.
- Out of scope: `mop-spec-ready-prod` (a release-level check across many
  tickets) and `mop-check-privilege` (run it when `spec-init` reports a
  privilege gap).

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
