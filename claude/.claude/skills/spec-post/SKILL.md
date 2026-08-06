---
name: spec-post
description: >-
  Sync the consolidated spec note to its Jira ticket: overwrite the description
  with the current spec (stamped round + date) and post a round-scoped change
  record as a comment with a curated subset of the private Open Questions. Use
  when a spec round is ready for the PM, confirming the spec with the PM,
  publishing/pushing the spec or its questions to Jira, or "spec-post MOP-XXXX".
  Requires the note from spec-init/spec-sync.
---

# Spec Post → publish the spec, record what changed

The last step of a spec round. `/spec-init` and `/spec-sync` keep a private,
consolidated artifact; this publishes it so the PM confirms the *whole*
understanding and answers the open questions **in round 1 instead of leaking them
across five**. Chat is ephemeral — a ticket is not.

Two write targets, one approval:

| Target | Holds | Lifecycle |
|--------|-------|-----------|
| **Description** | the current spec (規格 + Decision Log) | **overwritten** every round |
| **Comment** | what changed since the PM last saw it + the sign-off ask | append-only, one per round |

Description is current truth; comments are history. That is the same invariant the
note already keeps, and it is why the spec body is **never** posted as a comment —
one canonical copy, on the ticket, always current.

This is the **only write path to Jira** in this setup, and it is PM-visible.
Nothing is sent without an explicit approval in the same session.

`SKILL_DIR` = `~/.claude/skills/spec-post`.

## Prerequisites

- `specs/MOP-XXXX.md` exists. If not, stop — run `spec-init` first.
- **`JIRA_TOKEN`** (`source ~/.zshrc`). The fetch surfaces a clean error if the token is wrong.
- Scripts: `~/bin/fetch-ticket.sh`, `~/bin/md2jira.sh`, `~/bin/jira-comment.sh`,
  `~/bin/jira-description.sh`.

## Workflow

### 1. Load the note and its round

```bash
SPECS="$HOME/personal/office-note/Specs"
NOTE="$SPECS/MOP-XXXX.md"
```

Read it. Note the frontmatter `round: N`, the existing `posted:` entries (if any),
the last Round History date, and the Open Questions.

**The diff baseline is the last *posted* round**, not `N-1` — the newest `round:`
in `posted:`. When rounds 1-2 were never posted and round 3 is, the PM's delta
spans 01 → 03; anything else reports a change history they never saw. No `posted:`
entries at all = **first post** (see step 5).

### 2. Fetch + run the guards (delegated)

Delegate to a **general-purpose subagent**, run in the foreground (step 3
depends on its output). Give it `MOP-XXXX`, the note's frontmatter (`round`,
`posted:` entries, last Round History date), and have it run:

```bash
OUT=$(mktemp -d)
~/bin/fetch-ticket.sh MOP-XXXX "$OUT" > "$OUT/manifest.json"
~/bin/jira-description.sh get MOP-XXXX > "$OUT/description.live"
```

`fetch-ticket.sh` gives HTML-stripped plain text — fine for reading comments, too
lossy to archive or ownership-check a description. `jira-description.sh get`
returns the raw wiki markup, which is what a description guard needs.

Then have it run the four guards — all warn-and-confirm, none hard-block:

1. **Description ownership.** Empty (`! -s "$OUT/description.live"`) or carrying
   the `spec-post` stamp (step 4) → ours, overwrite freely, no prompt. **Foreign
   content** → flag it, and require the subagent to return that content
   **verbatim, in full** in its report. On approval (back in the main thread),
   archive it verbatim to a comment *before* overwriting:
   ```bash
   { echo "h3. 原 description 備份（spec-post 覆寫前，$(date +%F)）"; echo "{quote}";
     cat "$OUT/description.live"; echo "{quote}"; } > "$OUT/archive.wiki"
   ~/bin/jira-comment.sh MOP-XXXX "$OUT/archive.wiki"
   ```
   Match the stamp loosely — Jira round-trips wiki → ADF → wiki, so formatting
   shifts. The literal token `spec-post` in the panel body is the reliable anchor.
   A hand-edit made *inside* an owned description is silently overwritten; that is
   a knowingly accepted risk, and Jira's History tab is its undo path.
2. **Round already posted.** Scan `.comments[]` (authored by the user) for a
   `Round N` + `規格確認` header. Match loosely — the posted source contains
   escaped brackets (`\[Round 5\]`) while the manifest holds the *rendered* text.
   If present, **default to a description-only re-sync**: the PUT is idempotent and
   re-syncing after a typo fix is the normal reason to re-run, while a second
   comment duplicates a change record and re-notifies a human. Offer: proceed
   description-only (default), also post a new comment, or abort.
3. **Newer Jira activity.** Any comment whose `created` is later than the note's
   last Round History date is not folded into the spec. List author · date ·
   first line, and say they are unreflected. Offer `/spec-sync` first, or post anyway.
4. **Note drifted from its snapshot.**
   ```bash
   diff -u "$SPECS/.rounds/MOP-XXXX/round-NN.md" "$NOTE" | tail -n +3
   ```
   If it differs, report ±line counts and roughly which section, and state plainly
   that the note's **current** content is what will be published. Never rewrite an
   existing snapshot and never create a round N+1 — a round with no decisions in it
   is a lie.

Require the subagent's report to give a verdict + evidence for each of the four
guards (full verbatim text for guard 1 only if triggered). Present all triggered
guards together, once. Proceed on the user's confirmation.

### 3. Curate the questions

Eligible = **unchecked `- [ ]` items only**, anywhere under Open Questions.
`- [x]` / `~~struck~~` / `已解決` items are never posted.

Present them numbered, each with an **inferred audience** (PM / BE / internal) and
an include/exclude recommendation — e.g. a question about correcting a BE ticket's
privilege id is not a PM question. The user decides. Strip the
`· evidence: path:line` tail from anything that goes out; it is internal grounding
and reads as noise to a PM.

If nothing is unchecked, skip the comment entirely (see step 5) — the description
sync alone is the report.

### 4. Assemble the description (verbatim — do not retype the spec)

Extract `規格` and `Decision Log` **separately** — the latter is wrapped in a
collapsible macro, so it cannot go through the same pass as the ever-visible spec:

```bash
DRAFTS="/tmp/spec-post/MOP-XXXX"; mkdir -p "$DRAFTS"
awk '
  /^## /    { p = 0 }          # any H2 closes the previous section
  /^## 規格/ { p = 1 }
  p
' "$NOTE" > "$DRAFTS/spec.md"
awk '
  /^## Decision Log/ { p = 1; next }   # next: drop the heading, {expand} supplies its own title
  /^## /             { p = 0 }
  p
' "$NOTE" > "$DRAFTS/decisionlog.md"
```

**No heading demotion** on `spec.md` — the stamp panel is the header, so
`## 規格` → `h2.` sits right. (The comment path demotes; this one must not.)

Write the stamp panel first, then the spec body, then the Decision Log wrapped in
`{expand}` — panel and expand are already Jira markup, so they go in around the
`md2jira.sh` conversion, not through it:

```bash
cat > "$DRAFTS/description.wiki" <<EOF
{panel:title=Round N · 最後更新 $(date +%F)}
本規格由 spec-post 自動同步，每輪覆寫。
變更紀錄請見留言。
{panel}

EOF
~/bin/md2jira.sh < "$DRAFTS/spec.md" >> "$DRAFTS/description.wiki"
echo "" >> "$DRAFTS/description.wiki"
echo "{expand:title=Decision Log}" >> "$DRAFTS/description.wiki"
~/bin/md2jira.sh < "$DRAFTS/decisionlog.md" >> "$DRAFTS/description.wiki"
echo "{expand}" >> "$DRAFTS/description.wiki"
```

- The date is **today** — "last updated" describes the text the reader is looking
  at, not when the round happened.
- The panel doubles as the ownership sentinel for guard 1, and `spec-post` is the
  token that is matched. Keep that word in the body verbatim.
- Decision Log stays collapsed by default so it doesn't push the actual spec below
  the fold as rounds accumulate — a PM opens it only when they want the history.
- **Excluded, always:** frontmatter, the `# [MOP-XXXX] …` title, the `> Jira:` /
  `> Parent:` metadata lines, the header callouts, 技術檢查結論, Open Questions,
  Round History. The callouts are dropped deliberately: `本子票 description 為空`
  becomes false the moment the description is written.
- Warn if the result exceeds ~30,000 chars (`wc -m`); Jira's field limit is 32,767
  and `jira-description.sh set` refuses past it.

### 5. Assemble the comment

The comment is **question-only** — no framing sentence, no change table, no
closing ask, no ticket number in the title. What changed is already current
truth in the description's Decision Log; the comment exists purely to carry the
sign-off ask to a human.

Write `$DRAFTS/comment.md` in this order:

1. `[~accountid:<id>]` (omit the line entirely if no mention)
2. `## [Round N] 規格確認` (no `— MOP-XXXX`; the ticket is already the page you're on)
3. `### 需要確認` — the curated questions as a numbered list

If nothing is unchecked in Open Questions, skip posting a comment entirely —
there is nothing left to ask, and a description-only sync notifies no one.

Body language is Traditional Chinese (it is the note's language and the PM's).

```bash
~/bin/md2jira.sh < "$DRAFTS/comment.md" > "$DRAFTS/comment.wiki"
```

### 6. Resolve the mention target

Only when a comment is being posted — a description-only re-sync notifies nobody.

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

### 7. Get approval

Both drafts live at stable paths, overwritten on every re-render, so an editor left
open on them refreshes in place:

```
/tmp/spec-post/MOP-XXXX/description.wiki
/tmp/spec-post/MOP-XXXX/comment.wiki
```

Show a summary in-session — target ticket, round, both paths with char counts,
whether the description is empty / ours / foreign, who gets notified (by name),
question count, and every triggered guard — and tell the user to review the files.
The user revises by telling you what to change; re-render in place and re-show.
Write only on an explicit approval.

### 8. Write — description first, comment second

```bash
~/bin/jira-description.sh set MOP-XXXX "$DRAFTS/description.wiki"   # prints browse URL
~/bin/jira-comment.sh      MOP-XXXX "$DRAFTS/comment.wiki"          # prints comment URL, skip if no comment (step 5)
```

The order is not cosmetic: the PUT is idempotent and the comment POST is not, so
the un-retryable write goes last. If the comment fails, the description is already
current truth and the comment can simply be retried — nothing is duplicated. If it
succeeds and something later fails, **never re-run the whole flow** to fix it.

### 9. Record it in the note

Append to the frontmatter `posted:` list (create the key if absent). `url:` keeps
its existing meaning — the comment URL — so old entries and the step-1 baseline
lookup still parse:

```yaml
posted:
  - round: 5
    date: 2026-07-26
    url: https://morrisonexpress.atlassian.net/browse/MOP-27443?focusedCommentId=123456
    description: synced
  - round: 5
    date: 2026-07-27
    description: resynced      # description-only re-sync — no comment, so no url
```

Nothing else in the note changes, and **do not re-snapshot** — posting is not a
round. If this write fails after a successful post, report the URLs prominently so
they can be added by hand; never re-post to "fix" it.

### 10. Report

Description URL + round + char count, comment URL, who was notified, which
questions went out and which were held back (and why), whether an original
description was archived, and any guard that was overridden.

## Rules

- **Never write without explicit in-session approval.** No silent sends, no retries.
- The description is **overwritten**; a description this skill does not own is
  never touched without showing it in full and archiving it first.
- Comments are append-only: a new comment per post; **never edit or delete an
  existing comment** — the PM may have replied to it.
- Description = current truth (規格 + Decision Log). History lives in comments.
- The spec body is **never** posted as a comment.
- Only unchecked Open Questions are eligible; evidence tails are stripped.
- The mention target is always asked, never inferred.
- The spec body is copied verbatim through the pipeline — never retyped or
  summarized, or the description stops matching the artifact.
- Guards warn; the user decides. The one thing that is not negotiable is approval.
