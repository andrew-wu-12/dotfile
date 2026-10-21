# Post → publish the spec, ask what is still open

The last step of a spec round. Init and sync keep a private, consolidated
note. This step publishes it, so the reader confirms the *whole*
understanding and answers the open questions in one round instead of five.

Two write targets, one approval:

| Target | Holds | Lifecycle |
|--------|-------|-----------|
| **Description** | the current spec body | **overwritten** every round |
| **Comment** | the open questions for this round | append-only, one per round |

The description holds current truth; comments hold history. The spec body
is **never** posted as a comment — one canonical copy, on the ticket.

This is the only write path to the tracker in this flow, and other people
may read it. Nothing goes out without an explicit approval in the same
session.

Read first: `schema.md`, `challenge.md`, the profile (its Post section).

## Prerequisites

- `$SPECS/<id>.md` exists. If not, stop — run `spec-init` first.
- The profile's tracker access works.

## Workflow

### 1. Load the note

```bash
NOTE="$SPECS/<id>.md"
DRAFTS="/tmp/spec-post/<id>"; mkdir -p "$DRAFTS"
```

Read it. Note `round: N`, the `posted:` entries, the last Round History
date, and Open Questions.

### 2. Challenge the draft

Run `challenge.md`. It warns; it does not block.

### 3. Fetch and run the guards

Run the profile's post fetch (delegated or inline as the profile says): the
ticket's comments, and the **live description in its raw form** — the
profile names the command. Then run the four guards. Each warns and asks
for confirmation; none hard-blocks.

1. **Description ownership.** If the description is empty or contains the
   literal token `spec-post`, it is ours — overwrite it freely, no prompt.
   Match the token loosely, not the stamp's exact formatting. If it carries
   **foreign content**, flag it and keep the content **verbatim, in full**.
   After approval, archive it to a comment with the profile's archive
   command *before* overwriting. A hand-edit made *inside* an owned
   description gets silently overwritten — a known, accepted risk; the
   tracker's history is the undo path.
2. **Round already posted.** Scan the profile's own-author comments for the
   profile's comment header with this `Round N`. Match loosely. If one
   exists, **default to a description-only re-sync**: the description write
   is idempotent, and a typo fix is the normal reason to re-run. A second
   comment duplicates a record and re-notifies people. Offer: description
   only (default), also post a new comment, or abort.
3. **Newer tracker activity.** Flag every comment created after the note's
   last Round History date — the spec does not reflect it yet. List each as
   author, date, first line. Offer: run `spec-sync` first, or post anyway.
4. **Note drifted from its snapshot.**
   ```bash
   diff -u "$SPECS/.rounds/<id>/round-NN.md" "$NOTE" | tail -n +3
   ```
   (`NN` = current round.) If it differs, report the line-count delta and
   roughly which section changed. Say plainly that the note's **current**
   content is what gets published. Never rewrite a snapshot, and never
   create round N+1 for this — a round with no decisions is a lie.

A delegated fetch reports a verdict and evidence per guard, with guard 1's
full verbatim text only when it triggers. Present all triggered guards
together, once. Proceed only after the user confirms.

### 4. Curate the questions

Eligible items follow the profile's postable rule. Never post `- [x]`,
struck-through, or resolved items.

Present eligible items numbered, each with an include/exclude
recommendation. The user makes the final call. Strip the
`· evidence: path:line` tail from anything that goes out — it is internal
grounding.

If nothing is eligible, skip the comment entirely (step 6).

### 5. Assemble the description (verbatim — do not retype the spec)

Extract the body section only, by the profile's body heading:

```bash
awk -v h="<profile body heading>" '
  /^## /           { p = 0 }
  $0 == h || index($0, h " ") == 1 { p = 1 }
  p
' "$NOTE" > "$DRAFTS/spec.md"
```

Everything else in the note — frontmatter, title, link lines, callouts,
Open Questions, Decision Log, Round History — stays private.

Put the profile's stamp first, then the body, in the profile's description
format.

- The stamp uses **today's** date: "last updated" describes the text the
  reader sees now.
- The stamp is guard 1's ownership sentinel. Keep the token `spec-post` in
  it verbatim.

### 6. Assemble the comment

The comment is **question-only**: no framing sentence, no change table, no
closing ask, no ticket number in the title. Use the profile's comment
template, in the profile's note language. If nothing is eligible (step 4),
skip it — a description-only sync notifies no one.

### 7. Resolve the mention target

Only if the profile defines a mention step and a comment is going out.
A mention sends a real notification to a named person.

### 8. Get approval

The drafts live at stable paths under `$DRAFTS`; each re-render overwrites
them in place, so an editor left open refreshes.

Show a summary in-session: target ticket, round, both draft paths with
character counts, whether the description is empty/ours/foreign, who gets
notified (by name), the question count, the challenge verdict, and every
triggered guard. Tell the user to review the files. The user revises by
telling you what to change; re-render in place and show the summary again.
Write only after an explicit approval.

### 9. Write — description first, comment second

Use the profile's write commands, in this order. The description write is
idempotent; the comment write is not, so it goes last. If the comment
fails, the description is already current truth — retry the comment alone.
If the comment succeeds and something later fails, **never re-run the whole
flow** to fix it.

### 10. Record it in the note

Append to frontmatter `posted:` (create the key if missing) per
`schema.md`: `description: synced` for a first sync of the round,
`resynced` for a re-sync (no `url:` — no comment went out). Then apply the
profile's vault-commit rule (`<step>` = `post`).

Nothing else in the note changes. **Do not re-snapshot** — posting is not a
round. If this write fails after a successful post, report the URLs
prominently so the user can add the entry by hand. Never re-post to fix it.

### 11. Report

Description URL, round, character count, comment URL, who was notified,
which questions went out and which were held back (and why), whether an
original description was archived, the challenge verdict and any overridden
findings, and any overridden guard.
