# Init → durable spec artifact

Turn a ticket into a persistent, versioned spec note. The note accumulates
across rounds and reconciles every channel into one source of truth. It is
grounded in the real repos, not just the ticket text.

Read first: `schema.md`, `body.md`, `interview.md`, the profile.

## Prerequisites

- The profile's tracker access works.
- The profile's grounding repos are on disk.
- If `$SPECS/<id>.md` **already exists**, stop — this is a later round. Tell
  the user to run `spec-sync` instead.

## Workflow

### 1. Fetch the ticket

Run the profile's fetch for the whole ticket (no since-date): title,
description, every comment, every attachment. **Read every image yourself**
— prototype screenshots are part of the spec. Then do the profile's init
extras (e.g. record a prototype URL, derive the slug).

### 2. Ground in the codebase

Run the profile's grounding checks, delegated or inline as the profile
says. Give a delegated subagent the ticket content from step 1 and the
repo paths. Require, delegated or not:

- one finding per check, or "none found"
- `path:line` evidence only — no raw grep dumps or file contents
- **no guessing**: if the ticket does not state something, record it as
  unstated. Never infer it.

### 3. Interview the user on gaps

Run `interview.md`'s loop on the "missing details" findings before writing
anything, including the follow-ups the answers raise.

### 4. Generate the consolidated spec

Write the spec body per `body.md` and the profile's body rules. Use only
concrete details from the ticket, its images, the codebase, and step 3's
answers. **Do not invent** fields, APIs, config, ports, or behaviors.

If drafting surfaces a new gap, do not guess and do not file it straight to
Open Questions. Collect the gaps, re-enter `interview.md`'s loop, and update
the draft. Repeat until drafting surfaces nothing new.

### 5. Assemble Open Questions (private)

Every gap still waiting after steps 3–4 becomes a checkbox with its
`path:line` evidence and its `⏳` marker. This list stays private until
`spec-post` curates it. Keep each question specific and quotable.

### 6. Write the note, then snapshot

Write `$SPECS/<id>.md` from the profile's template. Decision Log rows and the
Round History entry use the profile's note language. Then:

```bash
~/bin/spec-snapshot.sh "$SPECS" <id>   # creates round-01
```

Run the snapshot **last**, after the note is written, so `round-01.md`
matches the end-of-round-1 state. Then apply the profile's vault-commit rule
(`<step>` = `init`).

### 7. Report

In English:
- Open Questions, grouped by waiting bucket
- Cross-source conflicts (ticket text vs. what is actually in the repos)
