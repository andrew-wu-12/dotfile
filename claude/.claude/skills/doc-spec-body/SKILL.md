---
name: doc-spec-body
description: >-
  Write or rewrite the 規格 (consolidated spec body) section of a spec note:
  field/API/test-scenario formats, business-level terms only, and the
  decision-log boundary. Used by spec-init (initial write) and spec-sync
  (rewrite to current truth) — not meant to be invoked on its own.
---

# Doc Spec Body → shape of the 規格 section

The shared rules for what `規格` is allowed to say, regardless of whether it
is being written for the first time (`spec-init`) or rewritten to current
truth (`spec-sync`). Both skills invoke this instead of restating these
rules — duplicating them once already let one drift out of sync (`spec-init`
silently lost the business-level-terms rule during an edit; this skill is why
that can't happen again).

## Language

Write `規格` in Traditional Chinese.

## Format per section

- **Frontend fields** — use `doc-field-table-spec`'s table format.
- **API payloads** — show a Request/Response JSON example per endpoint, not a
  description. Use `[MISSING]` for any value the source does not state.
- **Test scenarios** — one Precondition/Action/Expected-Result block per
  scenario, covering the main flow plus its edge and negative cases.

## Business-level terms only

- **Show**: pages (`{module_name} - {page_name}`), data fields, i18n keys, and
  API endpoints.
- **Avoid**: file paths, component names, function names, hook names, routes,
  URLs, or code constants.

## Decision-log boundary

If a decision is really about *how* to implement something — a library
choice, a code pattern — put it in the Decision Log, not in `規格`. `規格`
states observable behavior only, not the implementation mechanism.

## Formatting

When a `規格` sentence carries more than one fact, keep it short and use a
bullet list instead. If a table cell would need more than one line, move
that content to its own bullet group below the table.

## Prose style — 使用者操作 / 視圖邏輯

- **One state per top-level bullet, parallel across the whole doc.** When
  behavior branches on a state (e.g. record/dispatch status), give each state
  its own top-level bullet, phrased the same way every time it recurs
  (across 使用者操作, 視圖邏輯, and 測試案例情境) — don't bury a state
  condition inside a prose clause of another bullet.
- **State the bare fact. No justification asides.** Drop parentheticals that
  explain *why* something is the way it is or that it isn't changing —
  `(現有行為)`, `(不新增文案)`, `(沿用現有 XXX 流程)`, restating a value
  already given elsewhere. If it's worth explaining why, that belongs in the
  Decision Log, not in `規格`.
- **One action per bullet.** Don't chain multiple effects into one sentence
  with "並/然後". Split into sibling bullets, one effect each, even if that
  means a deeper indent level.
- **Only new or changed behavior gets a bullet.** Omit restatements of
  pre-existing, unchanged behavior (e.g. "此功能沿用現有 X privilege，不變"
  or "Y 沿用現有流程，本張 ticket 不新增規格") — if it isn't changing, it
  doesn't need a sentence in `規格`. Reserve confirmation of "checked, no
  change" for a Decision Log row instead.
