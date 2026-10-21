# Profile: mop

MOP frontend tickets on Jira. Spec notes are in the `office-note` vault.

## Identity and paths

- ID: the Jira key, `MOP-XXXX`. `<id>` is the key.
- Branch: `feature/MOP-XXXX`.
- `SPECS` = `$HOME/personal/office-note/Specs`.
- Vault-commit rule: do not commit. The vault commits itself.

## Tracker

- Channels: the Jira ticket, chat with the PM, the prototype images (Jira
  attachments).
- Access: the Jira token in the credential store, through
  `~/bin/cred-read.sh`.
- You: your Jira account. A comment is yours when its author is your
  `displayName`:
  ```bash
  curl -s -u "$(~/bin/cred-read.sh morrisonexpress.atlassian.net)" \
    https://morrisonexpress.atlassian.net/rest/api/2/myself | jq '{displayName, accountId}'
  ```
- Fetch: **delegated**. Start a fresh subagent in the foreground. It uses
  `tool-ticket-get`. Give it the ticket ID and the last Round History date.
  It returns each new comment word for word and the file path of each new
  attachment. It does not describe the attachments.
- Init extras: record each Figma or prototype URL. Put the first one in
  frontmatter `prototype`.

## Grounding

- Repos: `$MOP_MONOREPO_PATH`, `$MOP_CONFIGURATION_PATH`.
- Run: **delegated**, a fresh subagent in the foreground.
- Checks:
  1. **Similar feature?** Search `$MOP_MONOREPO_PATH/apps` and `/libs` for
     related pages, components, and routes. If one exists, align the spec
     with it. Report each difference.
  2. **Missing details?** Find what the ticket does not state: error
     handling, validation rules, empty, loading, and permission states,
     field behavior.
  3. **i18n keys?** Collect the UI strings. Check all of them in one call:
     ```bash
     ~/bin/check-i18n.sh --batch <<< $'Submit\nConsol No.'          # all modules
     ~/bin/check-i18n.sh --batch tms <<< $'Submit\nConsol No.'      # one module + commons
     ```
     The output for each string is `EXACT_KEY_MATCH`, `EXACT_VALUE_MATCH`,
     `SIMILAR_MATCHES`, or `NO_MATCH`, with the full `<module>.<key>` path.
     Use the existing keys that match.
  4. **Breaks existing behavior?** Find existing behavior that the spec
     changes or breaks.
  5. **New privilege?** Check the three environment branches:
     ```bash
     git -C "$MOP_CONFIGURATION_PATH" fetch -q origin
     for b in dev uat master; do
       echo -n "$b: "; git -C "$MOP_CONFIGURATION_PATH" show origin/$b:privileges.json | grep -c '<privilege-id>'
     done
     ```
     Report the state per branch, for example "in dev, not in uat/master →
     promote". `mop-check-privilege` does the promotion.

## Note language

- Note: Traditional Chinese (spec body, Decision Log text, Round History
  summaries, Open Questions).
- Reports to the user: English.

## Frontmatter (in addition to schema.md)

- `tags` — includes `📥/🟧` and `spec`.
- `ticket` — the Jira key.
- `prototype` — the Figma or prototype URL, or empty.

## Decision Log and Open Questions

- Source tags: `jira`, `chat`, `pm`, `dev`.
- Waiting buckets: `待 PM 回覆`, `待後端回覆`.
- Change reasons: `〔PM 規格變動〕`, `〔Dev 理解錯誤〕`, `〔先前決議錯誤〕`,
  `〔新資訊〕`.
- Recommended reason: source `jira` or `pm` → `PM 規格變動`. Source `chat`
  from a developer → `新資訊`.
- Replaces suffix: `，取代 YYYY-MM-DD「…」`.
- Round History reason count: `（2 項 PM 規格變動、1 項新資訊）`.

## Spec body

Heading: `## 規格 (Consolidated Spec)`.

### Formats

- **Frontend fields** — the table format of `doc-field-table-spec`.
- **API payloads** — one Request/Response JSON example for each endpoint.
- **Test scenarios** — one Precondition/Action/Expected-Result block for
  each scenario. Include the main flow, the edge cases, and the error cases.

### Terms

- **Show**: pages (`{module_name} - {page_name}`), data fields, i18n keys,
  API endpoints.
- **Avoid**: file paths, component names, function names, hook names,
  routes, URLs, code constants.

### Prose style — 使用者操作 / 視圖邏輯

- Give each state its own top-level bullet, for example each record status.
  Use the same words for that state in 使用者操作, 視圖邏輯, and
  測試案例情境. Do not put a state condition inside a clause of a different
  bullet.
- Write bullets only for new or changed behavior. Do not write
  `此功能沿用現有 X privilege，不變` or `Y 沿用現有流程，本張 ticket 不新增規格`.
- Remove asides such as `(現有行為)`, `(不新增文案)`, `(沿用現有 XXX 流程)`.

### Challenge cross-references

- A field in an API request or response example that is not in the field
  table, or the reverse.

## Post

- Body heading match (for `awk -v h=`): `## 規格`.
- Scripts: `~/bin/md2jira.sh`, `~/bin/jira-comment.sh`,
  `~/bin/jira-description.sh`.
- Fetch and guards: **delegated**. A fresh subagent in the foreground uses
  `tool-ticket-get`. It records the temp dir of that fetch as `$OUT`. Then
  it gets the raw description:
  ```bash
  ~/bin/jira-description.sh get MOP-XXXX > "$OUT/description.live"
  ```
  Use `description.live`, not the manifest description, for guard 1 and
  the archive. Jira changes the markup format on each write, so match the
  stamp phrase only.
- Own-author comments: yours (Tracker "You"). Comment header: `Round N`
  and `規格確認`. The source has escaped brackets (`\[Round 5\]`). The
  manifest has the rendered text.
- Archive command (in the main session, after approval):
  ```bash
  { echo "h3. 原 description 備份（spec-post 覆寫前，$(date +%F)）"; echo "{quote}";
    cat "$OUT/description.live"; echo "{quote}"; } > "$OUT/archive.wiki"
  ~/bin/jira-comment.sh MOP-XXXX "$OUT/archive.wiki"
  ```
- Postable rule: post only unchecked items with `⏳ 待 PM 回覆`. Keep
  `⏳ 待後端回覆` items private. An unchecked item with no `⏳` was never
  asked: list it separately, tell the user to run `spec-sync`, and do not
  post it.
- Stamp phrase: `本規格由 spec-post 自動同步`.
- Description: Jira wiki markup in `$DRAFTS/description.wiki`. Do not
  demote headings. Do not send the panel through `md2jira.sh`:
  ```bash
  cat > "$DRAFTS/description.wiki" <<EOF
  {panel:title=Round N · 最後更新 $(date +%F)}
  本規格由 spec-post 自動同步，每輪覆寫。
  變更紀錄請見留言。
  {panel}

  EOF
  ~/bin/md2jira.sh < "$DRAFTS/spec.md" >> "$DRAFTS/description.wiki"
  ```
  Warn when `wc -m` is more than 30,000. The Jira limit is 32,767.
- Comment template: write `$DRAFTS/comment.md`, then
  `~/bin/md2jira.sh < "$DRAFTS/comment.md" > "$DRAFTS/comment.wiki"`:
  1. `[~accountid:<id>]` (no line when there is no mention)
  2. `## [Round N] 規格確認`
  3. `### 需要確認` — the selected questions, numbered
- Mention: always ask the user. Show the candidates by display name: the
  ticket reporter, the parent ticket reporter, recent commenters, or no
  mention.
  ```bash
  curl -s -u "$(~/bin/cred-read.sh morrisonexpress.atlassian.net)" -H "Content-Type: application/json" \
    "https://morrisonexpress.atlassian.net/rest/api/2/issue/MOP-XXXX?fields=reporter,parent" \
    | jq '{reporter: .fields.reporter | {displayName, accountId}, parent: .fields.parent.key}'
  ```
- Write commands:
  ```bash
  ~/bin/jira-description.sh set MOP-XXXX "$DRAFTS/description.wiki"   # prints browse URL
  ~/bin/jira-comment.sh      MOP-XXXX "$DRAFTS/comment.wiki"          # prints comment URL
  ```

## Drift

- Code repo: `$MOP_MONOREPO_PATH`, on `feature/MOP-XXXX`.
- Round-diff path (steps 2–4): **delegated** to a fresh subagent.
- Change kinds:
  - field id or name changed (for example `console_number_list` → `consol_number_list`)
  - field type changed (for example text → multi-select)
  - optional ↔ required, or a validation rule added or changed
  - API endpoint path, method, or payload key changed
  - i18n key changed
  - result column added, removed, or renamed
  - privilege id changed
- Search command (limit it to the app or module of the ticket):
  ```bash
  grep -rnIF -f "$VALUES" "$MOP_MONOREPO_PATH/apps/<app>" \
    --include='*.ts' --include='*.tsx' --include='*.vue'
  ```
- One-round scan: **cardinality**. Find code that expects one record where
  the spec does not say one.
  ```bash
  git -C "$MOP_MONOREPO_PATH" diff <base>...HEAD -- 'apps/<app>/**/*.ts' 'apps/<app>/**/*.tsx'
  ```
  `<base>` is the `<base>` of the Flow section. Do not use `main`.
  1. In the diff, find lookups that return one record: `.find(...)` on an
     array, or a function that returns `T | undefined` or `T` (not `T[]`).
     The key is an identifier (`*_id`, `*_no`, `*_number`, `*Id`,
     `*Number`). The result is an object with many fields. Ignore lookups
     of enums and type guards.
  2. For each lookup, write the key field and the target entity.
  3. Search the current spec round for the two names together:
     - The spec says one-to-one (`唯一`, `unique`, `一個…對應一個`): aligned.
       Do not report it.
     - The spec says one-to-many (`多筆`, `多個`, `list`, `multiple`):
       **Contradiction**.
     - The spec says nothing: **Soft finding**. Write "Confirm: can `<key>`
       map to more than one `<target>`?"
- One-round Contradiction blocks the flip: **no**. Report it.

## Ready

- PR CLI: `gh`. The spec gates need the VPN and the Jira token.
- PR view: `gh pr view --json number,isDraft,title,url,headRefName,body`.
  Draft signal: `isDraft`.
- CI and comments:
  ```bash
  gh pr checks <number>
  gh pr view <number> --json comments,reviews
  ```
- What CI does not run: PR CI runs unit tests (`nx affected -t test`,
  `continuous_integration.yml`) and builds (`nx affected -t build`,
  `knip_pr_build.yml`). PR CI does not run Cypress e2e. The e2e job is
  `.jenkins/e2e_testing/jenkinsfile`. It uses `branch: 'main'` and runs only
  with `E2E_TESTING_TAG`. A diff can break e2e while all checks pass.
- Reviewers: **yes**. Make the review-comment index.
- Bot requests: for each `libs/**` change, the PR description needs a
  Confluence link in its References block. The bot check shows `pass` when
  the link is missing. Read the bot comment. If the link is missing, warn
  and name `/doc-common-component-changelog`.

### Extra gate 3b: browser test results (BLOCKING for a current FAIL)

`mop-spec-verify` runs the scenarios of `### 3. 測試案例情境` in a browser.
It writes one row for each scenario. This gate reads the rows only. Do not
start a browser run from this gate.

```bash
RESULT="$WORKTREE_ROOT/mop-console-monorepo/MOP-XXXX.verify.json"
git rev-parse HEAD
```

Number the scenarios 1, 2, 3, … in order. A row is **current** when its
`sha` is `HEAD` and its `round` is the note `round`. Other rows are
**stale**.

- A current row is FAIL: **block**. Report the scenario number, the
  expected text, the actual text, and the screenshot path. Tell the user to
  fix the code or the spec, then run `/mop-spec-verify MOP-XXXX <n>` and
  `spec-ready`.
- Each scenario has a current PASS row: pass.
- Other cases: one warning. Name each scenario with no row, a stale row, or
  an INCONCLUSIVE row (with its reason). Give the command:
  `/mop-spec-verify MOP-XXXX <n> <n>`, or `/mop-spec-verify MOP-XXXX` when
  there is no record.
- No spec note, or no scenario: does not block.

A stale FAIL does not block.

### Gate 4: identifiers

- Pattern:
  ```bash
  git diff origin/main...HEAD | grep '^-' | grep -oE "(id|name|data-testid)='[^']+'|#[a-zA-Z_][a-zA-Z0-9_.-]*"
  ```
- Add by hand: exported symbols, i18n keys, API field names, CSS tokens,
  `classNamePrefix` tokens, `localStorage` keys, privilege ids.
- Search: **delegated** to a fresh subagent. Give it the identifier list,
  the old → new name of each rename, each new selector token, and the two
  checks below. It returns one verdict for each item, with `path:line`
  only.
  1. **Removed or renamed identifiers.** For each one:
     ```bash
     ~/bin/identifier-scope-check.sh '<identifier>' "$MOP_MONOREPO_PATH"
     ```
     Give the bare identifier only (`foo`, not `id='foo'`). Give it only
     when it matches `^[A-Za-z0-9_.:#/-]+$`. For other identifiers, use
     `grep -rnIF -f <file>` and sort the hits yourself.
     The script sorts the hits into out-of-scope and in-scope. Judge the
     in-scope hits only. The same name in a different feature is a
     different field. Trace each hit to the renamed identifier before you
     change it.
  2. **Selectors that now match two elements.** For each new selector
     token (a shared `classNamePrefix`, a CSS class, a `data-testid`
     pattern), count the matches before and after the change. If the count
     goes from 1 to 2 or more, check each call site. `.click()`, `.type()`,
     and `.should('have.value')` without a scope expect one element.
     `.first()`, `.eq()`, and `within()` set a scope. A call site without a
     scope is **Confirmed**.

### Step 5: review

- Run: **delegated** to a fresh subagent, with the scoped diff.
- Checklist:
  - **Effect re-run.** In development, React StrictMode runs mount, then
    cleanup, then mount. For each new or changed `useEffect`, check that
    setup sets again each value that cleanup removed (refs, flags).
  - **Components that run together.** Check components that run at the
    same time and use the same state. Example: a modal opens, and a
    listener in a different component continues below it. Read one level
    past the changed files if necessary.
  - **The value that arrives, not the type.** For each new or changed
    validator, schema, or type guard:
    1. Find the value that the field holds at run time.
    2. Follow the value from the API to the form, through each layer that
       changes it.
    3. `convertNullToString` (`libs/shared/util/buildable-utils`) changes
       each API `null` to `''`, at all levels. The empty value is `''`.
    4. `Yup.number()`, `Yup.date()`, and `Yup.array()` fail on `''` unless
       the schema transforms `''` first. `.nullable()` does not fix this.
       `Yup.number()` changes `''` to `NaN`.
    5. Write three cases for the field: empty, `null`, absent.
    6. If the submit button uses the schema, the form stays invalid and the
       user cannot continue.
    7. Search for two signals: code near the field that tests `=== ''`, and
       an English yup type error instead of the i18n message.
  - **Defects in a fix.** If the diff fixes an earlier finding, check that
    each changed item still has a purpose.

### Flip

```bash
gh pr ready <number>
```

Merge rule: CODEOWNERS requests the code owners. The user adds other
reviewers and merges.

## Flow

- Branch: the `mwt` worktree (`$WORKTREE_ROOT/mop-console-monorepo/MOP-XXXX`),
  or `$MOP_MONOREPO_PATH` on `feature/MOP-XXXX`.
- `<base>`: the PR base, `origin/<baseRefName>` from
  `gh pr view --json baseRefName`. With no PR, `origin/main`.
- Commit count: do not count the `Initial draft for branch …` commit that
  `mwt` makes.
  ```bash
  git rev-list --count --invert-grep --grep='^Initial draft for branch' <base>..HEAD
  ```
- PR lookup: `gh pr view --json number,isDraft,state` on the feature
  branch. No PR → none. `OPEN` with `isDraft` → draft. `OPEN` → ready.
  `MERGED` → merged. `CLOSED` → closed.
- Pre-ready steps (row 10): run `mop-spec-verify MOP-XXXX` only when the
  record (`$WORKTREE_ROOT/mop-console-monorepo/MOP-XXXX.verify.json`) has no
  current PASS row for a scenario. `mop-spec-verify` uses the one global
  `yarn serve` and sets the previous serve target again when it stops.
- Shipped check:
  ```bash
  git -C "$MOP_MONOREPO_PATH" fetch -q origin
  git -C "$MOP_MONOREPO_PATH" log origin/main --merges -E -1 \
    --grep='from [^ ]+/(feature|hotfix)/MOP-XXXX($|[^0-9])' --pretty='%h %s'
  ```
  Output → shipped.
- Shipped action: ask the user if `mop-spec-document MOP-XXXX` must run.
  Then the ticket is done.
- Not in the flow: `mop-spec-ready-prod` (one release, many tickets) and
  `mop-check-privilege` (run it when `spec-init` reports a privilege gap).

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
