---
name: changelog-confluence
description: >-
  Detect changes to shared/common modules (libs/**) on the current git branch in
  the MOP monorepo and publish a "Common Components Change Log" page per changed
  component to Confluence, following the MOP template. Use this whenever the user
  asks to document common-component changes, create a change log / changelog page,
  write up shared-module changes for release, publish a component change doc to
  Confluence, or "log my libs changes" — even if they don't say "Confluence"
  explicitly. Triggers on documenting changes to shared UI/util/data-access
  components before a release.
---

# Common Components Change Log → Confluence

Turn the shared-module (`libs/**`) changes on the current branch into one
Confluence change-log page per changed component, matching the MOP
"Common Components Change Logs" template.

Reproducing that template by hand is fiddly (exact storage-format table, Jira
macros, correct parent page), so the deterministic parts are scripted and your
job is the judgement: grouping files into meaningful components, drafting the
Traditional-Chinese wording, and confirming before anything goes live.

## Prerequisites

- Run from **inside the monorepo working tree** (`$MOP_MONOREPO_PATH`) — "current
  branch" means that repo's checked-out branch.
- **VPN connected** and `JIRA_TOKEN` in the environment (`source ~/.zshrc`). The
  same token authenticates both Jira and Confluence.

`SKILL_DIR` below = `~/.claude/skills/changelog-confluence`.

## Workflow

### 1. Detect changed common modules

```bash
"$SKILL_DIR/scripts/detect_changes.sh" [base]
```

- `base` defaults to `main`; the diff is three-dot (`main...HEAD`) so you only see
  what *this* branch introduced. Pass a `uat/*` branch when working off one.
- Output groups changed `libs/**` files by directory into **candidate**
  components, each with `is_new` / `change_tag` (新增 if every file in the group is
  brand-new, otherwise 調整).
- **No components?** Report "no `libs/**` changes on this branch — nothing to
  document" and stop. Don't create anything.

### 2. Refine components and confirm with the user

The script groups by raw directory, which is only a first guess — a component
whose change touches both `PhoneInput/PhoneInput.tsx` and `PhoneInput/hooks/…`
will appear as two groups. Merge such sub-directories back into the one component
the user would recognize (the folder under `src/lib/**` that *is* the component,
like the example `.../src/lib/CommonInputs/feature/PhoneInput`).

Then **show the user the proposed component → page mapping and wait for
confirmation** before continuing. This human-facing doc isn't worth publishing
off a wrong guess, and only the user knows the intended granularity.

### 3. Resolve ticket metadata

Parse the ticket from the branch name (`feature/MOP-XXXX`, `hotfix/MOP-XXXX`);
let the user override it if they pass one. Then:

```bash
"$SKILL_DIR/scripts/resolve_ticket.sh" MOP-XXXX
```

This returns `summary`, `issue_type`, `release_date` (預計上線日, already resolved
with the right precedence — see below), and `task_release_info`.

### 4. Compute the impact-scope suggestion

Suggest 影響範圍 by finding which apps depend on each changed lib:

```bash
npx nx graph --file=/dev/stdout 2>/dev/null   # or: npx nx affected:apps --base=main
```

Present the affected `apps/*` as a **suggestion** — a shared `uis` change can
light up nearly every app, so let the user trim it to the curated phrasing the
template uses (e.g. `Outbound Checking (CFS)`). If Nx is slow or errors, just ask
the user for the impact scope instead of blocking on it.

### 5. Build each page body and preview

For each confirmed component, fill `assets/table_template.xml` (copy it, don't
edit the asset). Field sourcing:

| Field | Source |
|-------|--------|
| `{{COMPONENT_NAME}}` | component folder name (prefer Task Release Info `module` if filled) |
| `{{RELEASE_DATE}}` | `release_date` from step 3, formatted `YYYY/MM/DD` |
| `{{CHANGE_ITEMS}}` | draft in Traditional Chinese, e.g. `新增 PhoneInput 元件和相關測試` — derive add-vs-modify from the file statuses |
| `{{CHANGE_REASON}}` | one Jira macro per ticket (fill `assets/jira_macro.xml`: `{{TICKET_KEY}}`, `{{TAG}}` = 新增/調整). Default to the branch ticket; ask the user if related tickets should be added |
| `{{UAT_URL}}` | `https://mop-<ticket-lowercased>.uat.morrison.express/` (prefer Task Release Info `url` if filled) |
| `{{RESULT_BUSINESS}}` | a one-sentence **business-angle** description of the outcome — see "異動結果 wording" below |
| `{{RESULT_PLACEHOLDER}}` | leave literally `TODO: 貼上測試結果截圖` — screenshots are pasted by hand in the browser |
| `{{IMPACT_SCOPE}}` | the finalized value from step 4 |
| `{{CODE_URL}}` | `https://github.com/MorrisonExpress/mop-console-monorepo/tree/main/<component_dir>` — point at **main** (permanent location), not the feature branch |

#### 異動結果 wording (business angle, not actual logic)

`{{RESULT_BUSINESS}}` captions what the reader should conclude from the result —
the outcome a **user or the business** now experiences, in Traditional Chinese.
Infer it from the code diff, then translate it out of code terms: describe *what
happens*, never *how*. Do not name functions, types, files, or components — those
belong in 異動項目. One sentence; add a second only for a genuinely distinct
outcome.

- ❌ actual-logic: 「`getSingleMenuItemUrl` 依選單結構遞迴回傳單一 menu item 的 URL」
- ✅ business-angle: 「使用者登入後若僅具單一功能權限，系統自動導向該功能頁面，免去手動點選」

Find the nearest legitimate angle even for non-feature changes — a perf tweak
becomes 「上傳照片區塊反應更即時」, a refactor that unlocks a feature says so. But
when the diff genuinely has no user-facing effect, state that plainly (e.g.
「內部邏輯調整，使用者操作行為不變」) rather than inventing impact. The rule that
makes this field trustworthy: **never assert business value the diff doesn't
support.**

Page **title**: `<YYYYMMDD release date> <ComponentName>` (e.g. `20250414 PhoneInput`).
Fall back to today's date only if no release date resolved.

Write each filled body to a temp file, then **show the user a rendered preview of
every page's field values in one summary and get a single explicit confirmation**
before publishing. Nothing is posted before this gate.

You can dry-run a body without publishing:

```bash
DRY_RUN=1 "$SKILL_DIR/scripts/publish_page.sh" "20250414 PhoneInput" /tmp/body.xml
```

### 6. Publish

After confirmation, for each component:

```bash
"$SKILL_DIR/scripts/publish_page.sh" "<title>" <body_file>
```

Defaults to space `MOP`, parent `3515940866` ("Common Components Change Logs").
If it exits `2` (`status:exists`), a same-title page already exists — **stop for
that page, show the user its URL, and don't overwrite.** Report each created
page's URL, and remind the user to paste the 異動元件 / 異動結果 screenshots in the
browser (the only fields left as placeholders).

## Release-date precedence (already implemented in resolve_ticket.sh)

`PM Release Date (customfield_10379)` is preferred over `Expected Due Date
(customfield_10329)` — PM Release Date is the PM-owned go-live date. Check the
current ticket first; if both are empty, walk up the parent chain to the epic
(stopping at initiative `MOP-24745` or a null parent) and apply the same order.
If nothing resolves, ask the user for the date.
