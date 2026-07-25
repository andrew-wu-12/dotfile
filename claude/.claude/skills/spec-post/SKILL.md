---
name: spec-post
description: >-
  Post the consolidated spec note to its Jira ticket as a round-scoped sign-off
  comment, with a curated subset of the private Open Questions. Use when a spec
  round is ready for the PM, when asking the PM to confirm the spec, pushing spec
  questions to Jira, or "spec-post MOP-XXXX". Requires the note created by
  spec-init / spec-sync.
---

# Spec Post → PM-facing sign-off comment

The last step of a spec round. `/spec-init` and `/spec-sync` keep a private,
consolidated artifact; this pushes it to Jira so the PM confirms the *whole*
understanding and answers the open questions **in round 1 instead of leaking them
across five**. Chat is ephemeral — a posted comment is not.

This is the **only write path to Jira** in this setup, and it is PM-visible.
Nothing is sent without an explicit approval in the same session.

`SKILL_DIR` = `~/.claude/skills/spec-post`.

## Prerequisites

- `specs/MOP-XXXX.md` exists. If not, stop — run `spec-init` first.
- **VPN + `JIRA_TOKEN`** (`source ~/.zshrc`). Do not hard-gate on `scutil --nc list`
  (false negatives while the VPN is up); let the fetch surface real errors.
- Scripts: `~/bin/fetch-ticket.sh`, `~/bin/md2jira.sh`, `~/bin/jira-comment.sh`.

## Workflow

### 1. Load the note and its round

```bash
SPECS="$HOME/self/SyncObsidianNote/005-Sources/公司筆記/specs"
NOTE="$SPECS/MOP-XXXX.md"
```

Read it. Note the frontmatter `round: N`, the existing `posted:` entries (if any),
the last Round History date, and the Open Questions.

### 2. Fetch the ticket — this feeds all three guards

```bash
OUT=$(mktemp -d)
~/bin/fetch-ticket.sh MOP-XXXX "$OUT" > "$OUT/manifest.json"
```

### 3. Run the three guards — all warn-and-confirm, none hard-block

1. **Round already posted.** Scan `.comments[]` (authored by the user) for a
   `Round N` + `規格確認` header. Match loosely — the posted source contains
   escaped brackets (`\[Round 5\]`) while the manifest holds the *rendered* text.
   If present, say so with its date and offer: run `/spec-sync` first, or confirm
   an explicit re-post.
2. **Newer Jira activity.** Any comment whose `created` is later than the note's
   last Round History date is not folded into the spec. List author · date ·
   first line, and say they are unreflected. Offer `/spec-sync` first, or post anyway.
3. **Note drifted from its snapshot.**
   ```bash
   diff -u "$SPECS/.rounds/MOP-XXXX/round-NN.md" "$NOTE" | tail -n +3
   ```
   If it differs, report ±line counts and roughly which section, and state plainly
   that the note's **current** content is what will be posted. Never rewrite an
   existing snapshot and never create a round N+1 — a round with no decisions in it
   is a lie.

Present all triggered guards together, once. Proceed on the user's confirmation.

### 4. Curate the questions

Eligible = **unchecked `- [ ]` items only**, anywhere under Open Questions.
`- [x]` / `~~struck~~` / `已解決` items are never posted.

Present them numbered, each with an **inferred audience** (PM / BE / internal) and
an include/exclude recommendation — e.g. a question about correcting a BE ticket's
privilege id is not a PM question. The user decides. Strip the
`· evidence: path:line` tail from anything that goes out; it is internal grounding
and reads as noise to a PM.

If nothing is unchecked, that is fine — it becomes a spec-only confirmation post.

### 5. Resolve the mention target

**Always ask** — never auto-resolve. Offer the real candidates with display names:
the ticket reporter, the parent ticket's reporter (`.parent` in the manifest;
the reporter is often the PM when the sub-ticket was filed by the user), recent
commenters, or **no mention**. Get the `accountId` from Jira:

```bash
curl -s -u "$JIRA_TOKEN" -H "Content-Type: application/json" \
  "https://morrisonexpress.atlassian.net/rest/api/2/issue/MOP-XXXX?fields=reporter,parent" \
  | jq '{reporter: .fields.reporter | {displayName, accountId}, parent: .fields.parent.key}'
```

A mention fires a real notification at a named human. State who will be notified,
by name, in the approval step.

### 6. Assemble the draft (verbatim — do not retype the spec)

Extract the note's sections with a pipeline, so the spec is copied byte-for-byte
and headings are demoted one level to sit under the comment title:

```bash
DRAFT=$(mktemp).md
awk '
  /^## /              { p = 0 }          # any H2 closes the previous section
  /^## (背景|規格)/    { p = 1 }
  /^## Decision Log/  { p = 1 }
  /^> \[!/            { c = 1 }          # header-preamble Obsidian callout
  c && /^[^>]/        { c = 0 }
  p || c
' "$NOTE" | awk '/^```/{f=!f} !f && /^#/{sub(/^#/,"##")} 1' > "$DRAFT.body"
```

The callout rule matters: notes carry load-bearing warnings above the first `##`
(MOP-27443's "這不是全新開發，而是對齊既有頁面"). The `> Jira:` / `> Parent:` metadata
lines are deliberately *not* picked up — they are redundant on the ticket itself.
`md2jira.sh` renders callouts as the matching Jira macro (`{warning:title=…}`).

Then write `$DRAFT` in this order:

1. `[~accountid:<id>]` (omit the line entirely if no mention)
2. `## [Round N] 規格確認 — MOP-XXXX`
3. Framing line: this is the consolidated understanding across ticket / 討論 /
   prototype; please confirm it and answer the items below.
4. `$DRAFT.body` — 背景 (if present), 規格 (前端 / 後端 / 測試案例), Decision Log
5. `### 需要確認` — the curated questions as a numbered list
6. Closing ask: confirm if correct; answer the numbered items by number. **No deadline.**

**Excluded, always:** Round History, the `Open Questions` heading and its private
framing, checked/resolved questions, frontmatter.

Body language is Traditional Chinese (it is the note's language and the PM's).

### 7. Convert and get approval

```bash
~/bin/md2jira.sh < "$DRAFT" > "$DRAFT.wiki"
```

Show the **full converted wiki markup** in-session — there is no draft file to
review out of band. Lead with: target ticket, round number, who gets notified (by
name), question count, body line count, and any guard warnings. The user revises
by telling you what to change; re-render and re-show. Post only on an explicit
approval.

### 8. Post

```bash
~/bin/jira-comment.sh MOP-XXXX "$DRAFT.wiki"   # prints the comment URL
```

### 9. Record it in the note

Append to the frontmatter `posted:` list (create the key if absent):

```yaml
posted:
  - round: 5
    date: 2026-07-23
    url: https://morrisonexpress.atlassian.net/browse/MOP-27443?focusedCommentId=123456
```

Nothing else in the note changes, and **do not re-snapshot** — posting is not a
round. If this write fails after a successful post, report the comment URL
prominently so it can be added by hand; never re-post to "fix" it.

### 10. Report

Comment URL, round posted, who was notified, which questions went out and which
were held back (and why), and any guard that was overridden.

## Rules

- **Never post without explicit in-session approval.** No silent sends, no retries.
- Round-scoped and append-only: a new comment per post; **never edit or delete an
  existing comment** — the PM may have replied to it.
- Only unchecked Open Questions are eligible; evidence tails are stripped.
- The mention target is always asked, never inferred.
- The spec body is copied verbatim through the pipeline — never retyped or
  summarized, or the comment stops matching the artifact.
- Guards warn; the user decides. The one thing that is not negotiable is approval.
