---
name: hl-spec-sync
description: >-
  Merge new decisions into an existing homelab spec: re-fetch the Forgejo
  issue, extract decisions from a pasted chat log, flag contradictions
  across issue/chat/current spec, rewrite to current truth, and snapshot the
  round. Use after a discussion or spec change, when reconciling updated
  requirements, or "hl-spec-sync #N". Requires the note from hl-spec-init.
---

# HL Spec Sync → reconcile a new round

Fold a fresh round of decisions into the durable spec note. The spec lives
in two channels: the Forgejo issue, and chat or verbal discussion. Chat is
ephemeral. This skill surfaces contradictions between the channels and
records trustworthy decisions with their sources.

`SKILL_DIR` = `~/.claude/skills/hl-spec-sync`.

## Prerequisites

- `tea` authenticated (`tea login list` shows a login for
  `git.tailcb6113.ts.net`).
- `Homelab/2 - Specs/<issue>-<slug>.md` **must already exist** in
  `project-note`. If not, stop and tell the user to run `hl-spec-init`
  first.
- **The pasted chat/verbal log.** It arrives as the skill argument or in the
  user's message. If it is missing, ask the user to paste it — a rough
  summary is fine, no formatting required. A sync with no chat log is valid
  when only the issue changed. State that this is the case, then proceed
  with the issue alone.

## Workflow

### 1. Load current state

Read `Homelab/2 - Specs/<issue>-<slug>.md` — especially `## Spec`, the
Decision Log, and Open Questions. Note the current `round` from frontmatter
(new round = +1) and the last Round History date.

### 2. Re-fetch the issue

```bash
tea issues <N> --comments -o json -r andrew_wu/homelab
```

For anything new since the note's last Round History date, list each
comment verbatim (author, date, text). If a comment carries an image (rare
for infra work, but possible — e.g. a screenshot of an error), read it
directly; a new image can silently change the spec.

### 3. Extract decisions from the chat log

Pull concrete decisions from the pasted dump: config changes, scope cuts,
rule changes, new constraints. Ignore chatter. Tag each with source `chat`.

### 4. Cross-source contradiction check — the core step

For each changed item, compare its value across the issue, chat, and the
current spec. **List every contradiction explicitly.** Example:

> `RESTIC_BACKUP_PATH` — current spec: `/data/ntfy` · issue comment (08-20):
> `/data/ntfy` · chat (08-25): **`/data/ntfy-cache` excluded**. → chat is
> newer and explicit → resolve to excluded.

Resolution rule: prefer the **most recent explicit** decision. If two
sources conflict and neither has clear recency or authority, **do not
guess**. Add the conflict to Open Questions and flag it to the user instead
of silently picking one.

### 5. Rewrite to current truth

- Rewrite `## Spec` using `hl-doc-spec-body`'s conventions (English,
  subsection shape, decision-log boundary).
- If an item was checked this round and came back **unchanged**, leave its
  entry in `## Spec` exactly as it was. Do not narrate that you checked it —
  no "unchanged since Round N" callouts. If the "checked, no change" fact is
  worth keeping, record it as a Decision Log row instead.
- `## Spec` documents current truth only. It is not a diff log.
- **Append** to Decision Log (append-only): one dated, source-tagged row per
  decision this round.
- **Append** a Round History entry summarizing what changed (append-only).
- Update Open Questions: check off answered ones, add newly surfaced ones.
- Bump `round` in frontmatter.

### 6. Snapshot the round

```bash
~/bin/hl-spec-snapshot.sh <issue>-<slug>   # creates round-NN
cd ~/personal/project-note
git add "Homelab/2 - Specs/<issue>-<slug>.md" "Homelab/2 - Specs/.rounds/<issue>-<slug>/round-NN.md"
git commit -m "spec: sync #<issue> <slug>, round N"
```

Run this **last**, after the rewrite, so `round-NN.md` matches the
end-of-round-N state. This lets `hl-pr-ready`'s drift gate diff round-(N-1)
against round-N for exactly this round's change.

### 7. Report what changed

List, in English:
- New decisions with sources
- One-line "changed this round" summary
- Unresolved Open Questions
