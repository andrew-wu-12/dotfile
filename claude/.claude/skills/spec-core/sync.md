# Sync → reconcile a new round

Fold a fresh round of decisions into the durable spec note. The spec lives
in several channels (the profile lists them); chat is ephemeral. This step
surfaces contradictions between the channels and records trustworthy
decisions with their sources.

Read first: `schema.md`, `body.md`, `interview.md`, the profile.

## Prerequisites

- The profile's tracker access works. The fetch surfaces a clean error if it
  does not.
- `$SPECS/<id>.md` **must already exist**. If not, stop and tell the user to
  run `spec-init` first.
- **The pasted chat/verbal log.** It arrives as the skill argument or in the
  user's message. If it is missing, ask the user to paste it — a rough
  summary is fine. A sync with no chat log is valid when only the tracker
  changed. Say so, then proceed without it.

## Workflow

### 1. Load current state

Read the note — especially the spec body, Decision Log, and Open Questions.
Note the current `round` (new round = +1) and the last Round History date.

### 2. Re-fetch the tracker

Run the profile's fetch, delegated or inline as the profile says. For
anything new since the last Round History date, get each comment verbatim
(author, date, text) and the **file path** of every new image. A description
of what an image shows is not enough.

Then **you** (main thread) `Read()` every new image directly. A new
prototype or screenshot can silently change the spec. Treat every new image
as a decision source.

### 3. Extract decisions from the chat log

Pull concrete decisions from the pasted log: field, rule, config, endpoint,
and scope changes. Ignore chatter. Tag each with source `chat`.

### 4. Cross-source contradiction check — the core step

For each changed item, compare its value across every channel and the
current spec. **List every contradiction explicitly.** Example:

> `eta` field — current spec: optional · tracker comment (07-14): optional ·
> chat (07-15): **required**. → chat is newer and explicit → resolve to
> required.

Resolution rule: prefer the **most recent explicit** decision. If two
sources conflict and neither has clear recency or authority, **do not
guess** — it goes into step 5's queue.

### 5. Interview the user — loop until settled

Run `interview.md`'s loop before the rewrite. Queue:
- step 4's unresolved contradictions
- every unchecked Open Questions item from a prior round, with or without a
  `⏳` marker
- one change-reason question for every decision from steps 2–4

Follow-ups raised by answers join the queue, and each new decision they
produce gets its own reason question.

### 6. Rewrite to current truth

- Rewrite the spec body per `body.md` and the profile's body rules.
- If the rewrite surfaces a new gap or contradiction, do not guess. Re-enter
  step 5's loop, then continue. Repeat until the rewrite surfaces nothing new.
- **Append** to the Decision Log: one dated, source-tagged row per decision
  this round, prefixed with its change reason.
- **Append** a Round History entry summarizing what changed, ending with the
  per-reason count.
- Update Open Questions: check off answered items, add newly surfaced ones
  with their `⏳` marker.
- Bump `round` in frontmatter.

### 7. Snapshot the round

```bash
~/bin/spec-snapshot.sh "$SPECS" <id>   # creates round-NN
```

Run this **last**, after the rewrite, so `round-NN.md` matches the
end-of-round-N state and `spec-drift` can diff exactly this round's change.
Then apply the profile's vault-commit rule (`<step>` = `sync`).

### 8. Report what changed

In English:
- New decisions with sources and change reasons
- One-line "changed this round" summary
- Unresolved Open Questions, grouped by waiting bucket
