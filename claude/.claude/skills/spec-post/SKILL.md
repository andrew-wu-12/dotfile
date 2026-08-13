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
consolidated artifact. This skill publishes it, so the PM confirms the *whole*
understanding and answers the open questions **in round 1 instead of across
five separate rounds**. Chat is ephemeral. A ticket is not.

Two write targets, one approval:

| Target | Holds | Lifecycle |
|--------|-------|-----------|
| **Description** | the current spec (規格 + Decision Log) | **overwritten** every round |
| **Comment** | what changed since the PM last saw it + the sign-off ask | append-only, one per round |

Description holds current truth; comments hold history. The note already keeps
this same rule. This is why the spec body is **never** posted as a comment —
there is one canonical copy, on the ticket, always current.

This is the **only write path to Jira** in this setup, and the PM sees it.
Nothing goes out without an explicit approval in the same session.

`SKILL_DIR` = `~/.claude/skills/spec-post`.

## Prerequisites

- `specs/MOP-XXXX.md` exists. If not, stop — run `spec-init` first.
- **`JIRA_TOKEN`** (`source ~/.zshrc`). The fetch surfaces a clean error if the token is wrong.
- Scripts: `~/bin/md2jira.sh`, `~/bin/jira-comment.sh`, `~/bin/jira-description.sh`.

## Workflow

### 1. Load the note and its round

```bash
SPECS="$HOME/personal/office-note/Specs"
NOTE="$SPECS/MOP-XXXX.md"
```

Read it. Note the frontmatter `round: N`, any existing `posted:` entries, the
last Round History date, and the Open Questions.

**The diff baseline is the last *posted* round** — the newest `round:` value
inside `posted:` — not `N-1`. Example: rounds 1 and 2 were never posted, and
round 3 now is. The PM's delta then spans round 01 to round 03. Any other
baseline reports a change history the PM never saw. No `posted:` entries at
all means this is the **first post** (see step 5).

### 2. Fetch + run the guards (delegated)

Delegate to a **fresh subagent**. Run it in the foreground — step 3 needs its
output first. Give it the note's frontmatter (`round`, `posted:` entries, last
Round History date) from step 1 and the four guard rules below. Have it use
`tool-ticket-get` to fetch the ticket, note the temp dir that fetch creates as
`$OUT`, then also run:

```bash
~/bin/jira-description.sh get MOP-XXXX > "$OUT/description.live"
```

`tool-ticket-get`'s manifest gives HTML-stripped plain text. That text is fine
for reading comments, but it loses too much detail to archive or to
ownership-check a description. `jira-description.sh get` returns the raw wiki
markup instead — that is what a description guard needs.

Then have it run the four guards. Each guard warns and asks for confirmation.
None of the four hard-blocks:

1. **Description ownership.** If the description is empty
   (`! -s "$OUT/description.live"`) or carries the `spec-post` stamp (step 4),
   it is ours — overwrite it freely, with no prompt. If it carries **foreign
   content**, flag it, and require the subagent to return that content
   **verbatim, in full** in its report. After approval (back in the main
   thread), archive it verbatim to a comment *before* you overwrite it:
   ```bash
   { echo "h3. 原 description 備份（spec-post 覆寫前，$(date +%F)）"; echo "{quote}";
     cat "$OUT/description.live"; echo "{quote}"; } > "$OUT/archive.wiki"
   ~/bin/jira-comment.sh MOP-XXXX "$OUT/archive.wiki"
   ```
   Match the stamp loosely. Jira round-trips wiki markup through ADF and back
   to wiki, so formatting shifts each time. The literal token `spec-post` in
   the panel body is the reliable anchor. A hand-edit made *inside* an owned
   description gets silently overwritten. That is a known, accepted risk;
   Jira's History tab is the undo path.
2. **Round already posted.** Scan `.comments[]`, filtered to comments authored
   by the user, for a `Round N` + `規格確認` header. Match loosely: the posted
   source contains escaped brackets (`\[Round 5\]`), while the manifest holds
   the *rendered* text. If a match exists, **default to a description-only
   re-sync**. The PUT is idempotent, and re-syncing after a typo fix is the
   normal reason to re-run it. A second comment, by contrast, duplicates a
   change record and re-notifies a human. Offer three choices: proceed
   description-only (the default), also post a new comment, or abort.
3. **Newer Jira activity.** Flag any comment whose `created` date is later
   than the note's last Round History date — the spec does not reflect it yet.
   List each one as author, date, first line. Offer two choices: run
   `/spec-sync` first, or post anyway.
4. **Note drifted from its snapshot.**
   ```bash
   diff -u "$SPECS/.rounds/MOP-XXXX/round-NN.md" "$NOTE" | tail -n +3
   ```
   If it differs, report the line-count delta and roughly which section
   changed. State plainly that the note's **current** content is what gets
   published. Never rewrite an existing snapshot, and never create a round
   N+1 for this — a round with no decisions in it is a lie.

Require the subagent's report to give a verdict and evidence for each of the
four guards. Include the full verbatim text for guard 1 only when it
triggers. Present all triggered guards together, once. Proceed only after the
user confirms.

### 3. Curate the questions

Eligible items are **unchecked `- [ ]` items only**, anywhere under Open
Questions. Never post `- [x]`, `~~struck~~`, or `已解決` items.

Present them numbered. For each, infer an audience (PM, BE, or internal) and
give an include/exclude recommendation. Example: a question about correcting a
BE ticket's privilege id is not a PM question. The user makes the final call.
Strip the `· evidence: path:line` tail from anything that goes out — it is
internal grounding, and it reads as noise to a PM.

If nothing is unchecked, skip the comment entirely (see step 5). The
description sync alone is the report.

### 4. Assemble the description (verbatim — do not retype the spec)

Extract `規格` and `Decision Log` **separately**. The Decision Log is wrapped
in a collapsible macro, so it needs its own pass and cannot go through the
same pass as the always-visible spec:

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

**Do not demote headings** in `spec.md`. The stamp panel already acts as the
header, so `## 規格` maps correctly to `h2.`. (The comment path does demote
headings — that rule is different. This one must not.)

Write the stamp panel first, then the spec body, then the Decision Log wrapped
in `{expand}`. Panel and expand markup are already valid Jira markup, so add
them around the `md2jira.sh` conversion — do not run them through it:

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

- Use **today's** date. "Last updated" describes the text the reader is
  looking at now, not when the round happened.
- The panel also acts as the ownership sentinel for guard 1. `spec-post` is
  the token guard 1 matches. Keep that word in the body verbatim.
- The Decision Log stays collapsed by default, so it does not push the actual
  spec below the fold as rounds accumulate. A PM opens it only to see the
  history.
- **Always exclude:** frontmatter, the `# [MOP-XXXX] …` title, the `> Jira:`
  and `> Parent:` metadata lines, the header callouts, 技術檢查結論, Open
  Questions, and Round History. Drop the callouts deliberately: the moment
  you write the description, `本子票 description 為空` becomes false.
- Warn if the result exceeds ~30,000 characters (`wc -m`). Jira's field limit
  is 32,767 characters, and `jira-description.sh set` refuses anything past
  it.

### 5. Assemble the comment

The comment is **question-only**. Do not add a framing sentence, a change
table, a closing ask, or a ticket number in the title. What changed is already
current truth in the description's Decision Log. The comment exists only to
carry the sign-off ask to a human.

Write `$DRAFTS/comment.md` in this order:

1. `[~accountid:<id>]` (omit the line entirely if no mention)
2. `## [Round N] 規格確認` (no `— MOP-XXXX`; the ticket is already the page you're on)
3. `### 需要確認` — the curated questions as a numbered list

If nothing is unchecked in Open Questions, skip posting a comment entirely.
There is nothing left to ask, and a description-only sync notifies no one.

Body language is Traditional Chinese (it is the note's language and the PM's).

```bash
~/bin/md2jira.sh < "$DRAFTS/comment.md" > "$DRAFTS/comment.wiki"
```

### 6. Resolve the mention target

Do this step only when you are posting a comment — a description-only re-sync
notifies nobody.

**Always ask. Never auto-resolve.** Offer the real candidates with display
names: the ticket reporter, the parent ticket's reporter (`.parent` in the
manifest — often the PM, when the user filed the sub-ticket), recent
commenters, or **no mention**. Get the `accountId` from Jira:

```bash
curl -s -u "$JIRA_TOKEN" -H "Content-Type: application/json" \
  "https://morrisonexpress.atlassian.net/rest/api/2/issue/MOP-XXXX?fields=reporter,parent" \
  | jq '{reporter: .fields.reporter | {displayName, accountId}, parent: .fields.parent.key}'
```

A mention sends a real notification to a named person. State who gets
notified, by name, in the approval step.

### 7. Get approval

Both drafts live at stable paths. Each re-render overwrites the file in place,
so an editor left open on them refreshes automatically:

```
/tmp/spec-post/MOP-XXXX/description.wiki
/tmp/spec-post/MOP-XXXX/comment.wiki
```

Show a summary in-session: target ticket, round, both paths with character
counts, whether the description is empty, ours, or foreign, who gets notified
(by name), the question count, and every triggered guard. Tell the user to
review the files. The user revises by telling you what to change; re-render
the drafts in place and show the summary again. Write only after an explicit
approval.

### 8. Write — description first, comment second

```bash
~/bin/jira-description.sh set MOP-XXXX "$DRAFTS/description.wiki"   # prints browse URL
~/bin/jira-comment.sh      MOP-XXXX "$DRAFTS/comment.wiki"          # prints comment URL, skip if no comment (step 5)
```

This order matters. The PUT is idempotent; the comment POST is not. The
write you cannot safely retry goes last. If the comment fails, the
description is already current truth, and you can simply retry the comment —
nothing gets duplicated. If the comment succeeds and something later fails,
**never re-run the whole flow** to fix it.

### 9. Record it in the note

Append to the frontmatter `posted:` list — create the key if it does not
exist yet, per `doc-spec-schema`'s shape for this field. Write `description:
synced` for a first sync of the round, `resynced` for a re-sync (omit `url:`
in that case — no comment went out). This keeps old entries and the step-1
baseline lookup parsing correctly.

Nothing else in the note changes. **Do not re-snapshot** — posting is not a
round. If this write fails after a successful post, report the URLs
prominently so the user can add them by hand. Never re-post to "fix" it.

### 10. Report

Description URL + round + char count, comment URL, who was notified, which
questions went out and which were held back (and why), whether an original
description was archived, and any guard that was overridden.
