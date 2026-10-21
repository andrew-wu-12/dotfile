# Interview → loop until every question has an owner

Some gaps have a fast answer, and the person running the skill often knows
it. Ask first. Keep asking until every in-scope item is either answered or
explicitly waiting on someone else. Only then does the calling step write
the note and snapshot the round.

## Scope

- **init** — missing or unstated details (the "missing details" grounding
  check).
- **sync** — unresolved contradictions, every unchecked Open Questions item
  from a prior round (with or without a `⏳` marker), and the change reason
  for every decision this round (see below).
- **Both** — follow-up questions that an answer raises, and gaps found while
  drafting the spec body. The caller re-enters the loop after drafting, so a
  gap found during writing is asked, not filed.

The other grounding checks are evidence-backed findings, not questions. Do
not run this loop on them.

## The loop

Use `AskUserQuestion`, up to 4 questions per call. Repeat until nothing in
scope is left:

1. Ask the next batch.
2. Record each outcome (below).
3. If an answer raises a follow-up, add it to the queue — but only if its
   answer would change the spec body. There is no cap on rounds; the wait
   options let the user end any thread.

Every gap question offers one wait option per profile waiting bucket. Never
force an answer.

Re-asked open items (sync) go in batches of up to 4, each with a "still
waiting" option that keeps the item as it is.

## Change reason (sync only)

Every decision this round — changed, added, or answering an Open Question —
gets one reason question. An answer can carry new spec beyond the question
itself, so do not skip it. The options are the profile's change reasons.
Free text goes under "Other". Put the reason the profile recommends for the
decision's source first, with "(Recommended)". Batch these with the gap
questions in the same loop.

## Record the outcome

- **Answered** → one Decision Log row, `Source = dev`. Do not also add an
  Open Questions entry. If it answers an existing Open Questions item, check
  that item off with the answer (`schema.md`'s format).
- **Waiting** → an unchecked Open Questions item with a `⏳ <bucket>
  (YYYY-MM-DD)` marker dated today. A re-asked item that is still waiting
  keeps its original marker and date.
- **Change reason** → prefix the decision's Decision Log row with the reason
  in the profile's brackets (`schema.md`'s row format).

## If you cannot ask

With no interactive context (for example, a headless run), skip this loop.
File every in-scope gap to Open Questions **without** a `⏳` marker — no
marker means "never asked". Record no change reasons.
