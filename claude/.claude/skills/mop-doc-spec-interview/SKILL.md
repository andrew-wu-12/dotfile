---
name: mop-doc-spec-interview
description: >-
  Loop the user through spec gaps until every one is answered or marked as
  waiting on the PM or backend — before the note is written. Do not silently
  file gaps to Open Questions. mop-spec-init uses this for missing/unstated
  ticket details; mop-spec-sync uses this for contradictions, open questions, and
  change reasons. Do not invoke this skill on its own.
---

# Doc Spec Interview → loop until every question has an owner

Some gaps have a fast answer. The developer running the skill often knows
it. Ask first. Keep asking until every in-scope item is either answered or
explicitly waiting on someone else. Only then does the calling skill write
the note and snapshot the round.

## Scope

- **mop-spec-init** — missing/unstated ticket details (grounding check 2).
- **mop-spec-sync** — unresolved contradictions, every still-open Open Questions
  item from a prior round (with or without a `⏳` marker), and the change
  reason for every decision this round (see below).
- **Both** — follow-up questions that an answer raises, and gaps found while
  drafting `規格`. The caller re-enters the loop after drafting, so a gap found
  during writing is asked, not filed.

Grounding checks 1/3/4/5 are evidence-backed findings, not questions. Do not
run this step on them.

## The loop

Use `AskUserQuestion`, up to 4 questions per call. Repeat until nothing in
scope is left:

1. Ask the next batch.
2. Record each outcome (below).
3. If an answer raises a follow-up, add it to the queue — but only if its
   answer would change `規格`. No hard cap on rounds; the wait options below
   let the user end any thread.

Every gap question offers two wait options: `待 PM 回覆` and `待後端回覆`. Never
force an answer.

Re-asked open items (mop-spec-sync) go in one batch per 4, each with a "still
waiting" option that keeps the item as it is.

## Change reason (mop-spec-sync only)

Every decision this round — changed, added, or answering an Open Question —
gets one reason question. An answer can carry new spec beyond the question
itself, so do not skip it. The four options:

- `PM 規格變動`
- `Dev 理解錯誤`
- `先前決議錯誤`
- `新資訊`

Free text goes under "Other". Put the reason the source suggests first with
"(Recommended)" — a Jira/PM-chat item → `PM 規格變動`, a dev-chat item →
`新資訊`. Batch these with the gap questions in the same loop.

## Record the outcome

- **Answered** → one Decision Log row, `Source = dev`. Do not also add an
  Open Questions entry for it. If it answers an existing Open Questions item,
  check that item off with the answer (`mop-doc-spec-schema`'s format).
- **Waiting** → an unchecked Open Questions item with a `⏳` marker, dated
  today: `· ⏳ 待 PM 回覆 (YYYY-MM-DD)` or `· ⏳ 待後端回覆 (YYYY-MM-DD)`. A
  re-asked item that is still waiting keeps its original marker and date.
- **Change reason** → prefix the decision's Decision Log row with the reason
  in brackets, e.g. `〔PM 規格變動〕…`. See `mop-doc-spec-schema` for the row format.

## If you cannot ask

If there is no interactive context (for example, a headless run), skip this
step. File every in-scope gap to Open Questions **without** a `⏳` marker —
no marker means "never asked". Record no change reasons.
