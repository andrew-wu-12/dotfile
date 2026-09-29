---
name: mop-frontend-document
description: >-
  Write, audit, or restyle a MOP frontend feature note in the office-note
  vault (`Docs/**`) — the 系統操作 / 資料邏輯 / 驗證規則 / 重點 callout format,
  checked against the mop-console-monorepo source. Use this whenever the user
  asks to document a frontend feature, page, or module, to check what a note
  has got outdated or never documented, to write up how a screen works for
  someone new to it, to explain what a page can do, or names an existing note
  under `Docs/` to update — even if they never say "note" or "vault". Not for the Jira spec notes under `Specs/`; those belong
  to spec-init / spec-sync.
---

# MOP Frontend Document → feature notes in the office-note vault

These notes are written for someone who has never opened this module — a new
joiner, a PM, QA, whoever picks the screen up next year. They answer
「這個畫面能做什麼、怎麼運作」, not 「這個功能怎麼實作」. Everything below follows
from that: the note has to survive a refactor that renames every symbol in
the module, and a reader has to be able to check it by operating the screen
rather than by reading the source.

## Not the same job as a spec

`Specs/` (spec-init / spec-sync) is an implementation guide for the person
about to build a ticket, so it carries real logic, field-level rules, and
validation detail. A `Docs/` note is orientation material: what the page
offers, how the pieces connect, and the rules a user would actually run
into. When you are unsure whether something belongs, ask which of the two
readers needs it — if the answer is "the person writing the code", leave it
out.

## Where things live

- Note: `~/personal/office-note/Docs/<area>/<Feature>.md`,
  e.g. `Docs/M1 TMS/Fast Dispatch Create.md`
- Code: `~/project/mop-console-monorepo`
- `Specs/` is a different artifact (per-ticket Jira specs) — don't touch it
  from here.

## Read the code before writing a line

### Fix the baseline first

The notes describe shipped behaviour, so compare against `main`, not whatever
feature branch happens to be checked out:

```bash
git log --oneline -8 -- <feature-dir>          # what changed recently
git diff --stat main...HEAD -- <feature-dir>   # empty ⇒ tree matches main
```

Recent commit subjects are the cheapest signal you will get about where a
note has gone stale — a `feature(TMS): … dummy carrier` line tells you which
section is out of date before you have read a single component.

If the tree does *not* match `main`, either document `main` or say plainly in
the report which baseline you documented.

### Read in dependency order

Entry component → duck (API surface) → validations → utilities → configs →
child components. Reading the duck early pays off: it is the fastest map of
the feature, and every later file then tells you *when* a known endpoint
fires rather than *what* it is.

### Keep two lists as you read

One for 「文件寫錯了」, one for 「文件沒寫」, each item anchored to
`file:line`. The anchor is what makes a finding arguable instead of
assertive, and it is what lets the user overrule you in one sentence.

## Report before you rewrite

Auditing and rewriting are different jobs. Present the findings first and let
the user rule on them — some of what looks like a defect is intended
behaviour that only they know about. (A real case: a "the return value is
ignored" finding was wrong, because that endpoint throws on failure and the
existing wording was right. Rewriting first would have baked the mistake into
the note.)

Suspected code defects found along the way belong in the report, never in the
note and never silently fixed. Hand them over and let the user decide.

## Note structure

```markdown
# TMS - <Feature>

*來源：<where this came from>*
*程式碼位置：`apps/<app>/src/.../<Feature>/`*

<entry point sentence, then 3-5 bullets of the end-to-end flow>

## <Section>
> [!info] 系統操作
> <what the user sees, in prose>
>
> ```mermaid
> flowchart TD
> ```

> [!abstract] 資料邏輯（API）
> <what happens, and which endpoints are called>

> [!abstract] 驗證規則
> <what blocks, what only warns>

> [!warning] 重點
> <the traps>
```

Use the callout vocabulary as-is — `系統操作`, `資料邏輯` / `資料邏輯（API）`,
`驗證規則`, `重點`. `系統操作` is the spine — a reader should be able to
follow a section from that block alone, with the rest filling in detail they
can skip. `驗證規則` covers the rules a user runs into (what blocks, what
only warns), not every guard in the code. `重點` is the block that earns
its keep: shared code, two conditions that look alike but differ, an API
called from more than one place. If a section has no trap worth naming,
leave it out rather than padding it.

## Headings are API

Other notes link `[[Note#Heading]]`, so a heading rename silently breaks
them. Before restructuring:

```bash
grep -rn "\[\[<Note Name>" ~/personal/office-note --include=*.md
```

Keep every heading that has an inbound link, even when reorganising around
it. After editing, run the vault's own link check and leave the tree as you
found it:

```bash
cd ~/personal/office-note
git add -- <changed files> && .githooks/pre-commit && git reset
```

The hook rejects any `[[wikilink]]` that doesn't resolve inside the vault.
Don't commit unless asked.

## Writing style

The rules that keep a note readable by someone who has never seen the code:

- **Features and page logic first.** Lead with what the screen offers and how
  its parts connect; the rest of the note exists to support that. A useful
  test for any sentence: could the reader confirm it by operating the page,
  or would they have to open the source? The second kind usually belongs in
  a spec, not here.
- **No implementation mechanism.** How state is held, what re-renders, which
  layer owns a piece of data, the order internal helpers run in — none of it
  is visible to the reader and all of it changes without the behaviour
  changing. Describe the observable result instead.
- **No code identifiers.** No function, hook, component, internal state, or
  constant names. Describe the action — 「重新排序提單清單」 — not the symbol
  that performs it. Identifier names go stale far faster than behaviour does,
  and the reader can't grep for them anyway.
- **Keep the service contract, but don't let it take over.** HTTP method +
  path stays (`POST /us/tms_shipment/fast_creation`), and so do URL query
  parameter names and real data values the reader can see on screen (a
  carrier code of `TEMP` displayed as `Not known now`) — these say which
  system the page talks to and how it was reached, which is orientation, not
  implementation. The JS function wrapping the call is neither. Endpoints
  support the flow description; they are never the point of a section.
- **Action and flow validation only.** Skip data-transformation detail —
  sort comparators, payload trimming, calculation formulas. State the
  outcome in one line and move on.
- **No message text or i18n keys.** Write 顯示錯誤訊息／警告訊息／提醒訊息／
  確認對話框, and say whether it blocks or lets the user continue. Whether it
  blocks is the part a reader is actually looking for.
- **Business terms over field names**: 毛重、可計費重量、預計司機到達時間.
  Status values keep their display names (Planning、已指派車行、已送達).
- **Situational callout sub-titles.** 「驗證規則 — 按『下一步』時」, never a
  sub-title named after the function being described.

Mermaid node labels follow the same rules — they are the most common place
where identifiers leak back into a note.

## Dry-run a style change on one section

A style rule that reads unambiguously in a sentence has real judgement calls
hiding behind it: do endpoints count as identifiers, do URL params, do field
length limits survive the "no detail" rule. Rewrite one section, show it,
and list the calls you made so the user can correct them in one line —
then apply to the rest of the file.

## Let knock-on edits follow

Documenting a behaviour can falsify a sentence in a neighbouring note. After
a substantial addition, grep the vault for claims the new content
contradicts — a note that says 「這是唯一會呼叫 X 的地方」 stops being true
the moment you document the second caller. Fix it in the same pass and say
you did.
