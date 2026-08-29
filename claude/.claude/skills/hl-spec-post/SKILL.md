---
name: hl-spec-post
description: >-
  Sync the consolidated spec note to its Forgejo issue: overwrite the issue
  description with the current spec (stamped round + date) and post a
  round-scoped change record as a comment with a curated subset of the
  private Open Questions. Use when a spec round is ready to publish,
  confirming the spec on the issue, or "hl-spec-post #N". Requires the note
  from hl-spec-init/hl-spec-sync.
---

# HL Spec Post → publish the spec, record what changed

The last step of a spec round. `hl-spec-init` and `hl-spec-sync` keep a
private, consolidated artifact in `project-note`. This skill publishes it,
so the Forgejo issue always shows current state — readable from your phone,
from `prefix i`'s picker, or by future-you without opening the vault.

Two write targets, one approval:

| Target | Holds | Lifecycle |
|--------|-------|-----------|
| **Description** | the current spec (`## Spec`) | **overwritten** every round |
| **Comment** | what changed since it was last synced + open questions | append-only, one per round |

Description holds current truth; comments hold history. This is why the
spec body is **never** posted as a comment — there is one canonical copy, on
the issue, always current.

This is the only write path to the Forgejo issue that this flow uses.
Nothing goes out without an explicit approval in the same session.

`SKILL_DIR` = `~/.claude/skills/hl-spec-post`.

## Prerequisites

- `Homelab/2 - Specs/<issue>-<slug>.md` exists in `project-note`. If not,
  stop — run `hl-spec-init` first.
- `tea` authenticated (`tea login list` shows a login for
  `git.tailcb6113.ts.net`).

## Workflow

### 1. Load the note and its round

```bash
NOTE="$HOME/personal/project-note/Homelab/2 - Specs/<issue>-<slug>.md"
```

Read it. Note the frontmatter `round: N`, any existing `posted:` entries,
the last Round History date, and the Open Questions.

**The diff baseline is the last *posted* round** — the newest `round:`
value inside `posted:` — not `N-1`. Example: rounds 1 and 2 were never
posted, round 3 now is. The delta then spans round 01 to round 03. Any
other baseline reports a change history nobody actually saw on the issue.
No `posted:` entries at all means this is the **first post** (see step 4).

### 2. Fetch + run the guards

```bash
tea issues <N> --comments -o json -r andrew_wu/homelab
```

Run these four guards. Each warns and asks for confirmation. None hard-blocks:

1. **Description ownership.** If the issue body is empty, or carries the
   `hl-spec-post` stamp (step 4), it is ours — overwrite it freely, no
   prompt. If it carries **foreign content** (something you wrote by hand
   directly on the issue), flag it and quote it back in full. After
   approval, archive it verbatim to a comment *before* overwriting:
   ```bash
   tea comments add <N> -r andrew_wu/homelab \
     "**Original description (archived before hl-spec-post overwrite, $(date +%F))**

   > $(cat original.txt)"
   ```
2. **Round already posted.** Scan comments authored by `andrew_wu` for a
   `Round N` header match. If a match exists, **default to a
   description-only re-sync** — re-syncing after a typo fix is the normal
   reason to re-run this. A second comment duplicates a change record.
   Offer three choices: proceed description-only (default), also post a new
   comment, or abort.
3. **Newer issue activity.** Flag any comment whose `created` date is later
   than the note's last Round History date — the spec doesn't reflect it
   yet. List each as author, date, first line. Offer two choices: run
   `hl-spec-sync` first, or post anyway.
4. **Note drifted from its snapshot.**
   ```bash
   diff -u "$HOME/personal/project-note/Homelab/2 - Specs/.rounds/<issue>-<slug>/round-NN.md" "$NOTE" | tail -n +3
   ```
   (`NN` = current round.) If it differs, report the line-count delta and
   roughly which section changed. State plainly that the note's **current**
   content is what gets published. Never rewrite an existing snapshot, and
   never create a round N+1 for this — a round with no decisions in it is a
   lie.

Present all triggered guards together, once. Proceed only after the user
confirms.

### 3. Curate the questions

Eligible items are **unchecked `- [ ]` items only**, anywhere under Open
Questions. Never post `- [x]` or struck-through items.

Present them numbered. The user makes the final call on which go out. Strip
the `· evidence: path:line` tail from anything that goes out — it's
internal grounding, reads as noise on the issue.

If nothing is unchecked, skip the comment entirely (see step 5). The
description sync alone is the report.

### 4. Assemble the description (verbatim — do not retype the spec)

Extract `## Spec` only. The Decision Log is never posted — it stays private
to the note:

```bash
DRAFTS="/tmp/hl-spec-post/<issue>-<slug>"; mkdir -p "$DRAFTS"
awk '
  /^## /      { p = 0 }
  /^## Spec/  { p = 1 }
  p
' "$NOTE" > "$DRAFTS/spec.md"
```

Write the stamp line first, then the spec body verbatim:

```bash
{
  echo "> **Round N · last updated $(date +%F)** — synced by \`hl-spec-post\`;"
  echo "> full history in \`project-note/Homelab/2 - Specs/<issue>-<slug>.md\`."
  echo
  cat "$DRAFTS/spec.md"
} > "$DRAFTS/description.md"
```

- Use **today's** date — "last updated" describes the text the reader sees
  now, not when the round happened.
- The stamp line is also guard 1's ownership sentinel. `hl-spec-post` is
  the literal token guard 1 matches — keep that word verbatim.
- **Always exclude:** frontmatter, the `# [#N] …` title, the `> Forgejo:`
  link line, Decision Log, and Round History.

### 5. Assemble the comment

The comment is **question-only**. No framing sentence, no change table, no
closing ask. What changed is already current truth in the description.

```markdown
## [Round N] Spec confirmation

### Open
1. <question>
2. <question>
```

If nothing is unchecked in Open Questions, skip posting a comment entirely
— a description-only sync notifies nothing new.

### 6. Get approval

```
/tmp/hl-spec-post/<issue>-<slug>/description.md
/tmp/hl-spec-post/<issue>-<slug>/comment.md
```

Show a summary in-session: target issue, round, whether the description is
empty/ours/foreign, the question count, and every triggered guard. Tell the
user to review the files. The user revises by telling you what to change;
re-render in place and show the summary again. Write only after explicit
approval.

### 7. Write — description first, comment second

```bash
tea issues edit <N> -r andrew_wu/homelab --description "$(cat "$DRAFTS/description.md")"
tea comments add <N> -r andrew_wu/homelab "$(cat "$DRAFTS/comment.md")"   # skip if no comment (step 5)
```

This order matters. The description write is idempotent; the comment post
is not. The write you cannot safely retry goes last. If the comment fails,
the description is already current truth — just retry the comment, nothing
duplicates. If the comment succeeds and something later fails, **never
re-run the whole flow** to fix it.

### 8. Record it in the note

Append to the frontmatter `posted:` list — create the key if it does not
exist yet, per `hl-doc-spec-schema`'s shape for this field. Write
`description: synced` for a first sync of the round, `resynced` for a
re-sync (omit `url:` in that case — no comment went out).

```bash
cd ~/personal/project-note
git add "Homelab/2 - Specs/<issue>-<slug>.md"
git commit -m "spec: post #<issue> <slug>, round N"
```

Nothing else in the note changes. **Do not re-snapshot** — posting is not a
round. If this write fails after a successful post, report the issue URL
prominently so the user can add the `posted:` entry by hand. Never re-post
to "fix" it.

### 9. Report

Issue URL + round, whether an original description was archived, which
questions went out and which were held back (and why), and any guard that
was overridden.
