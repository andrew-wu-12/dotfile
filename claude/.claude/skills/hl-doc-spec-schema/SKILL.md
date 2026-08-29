---
name: hl-doc-spec-schema
description: >-
  Shared artifact schema for the homelab spec note: file path, frontmatter
  fields, and section headings. Used by hl-spec-init (creates the note),
  hl-spec-post and hl-pr-ready (read frontmatter fields) — not meant to be
  invoked on its own.
---

# Doc Spec Schema (homelab) → shape of the spec artifact

The shared structural facts about the homelab spec note — where it lives,
what its frontmatter fields mean, and what sections it has — regardless of
which skill is creating, reading, or updating it. `hl-spec-init`,
`hl-spec-sync`, `hl-spec-post`, and `hl-pr-ready` all reference this instead
of restating it.

## Artifact location

- Vault repo: `~/personal/project-note` (a git submodule of the main
  Obsidian vault, `git@forgejo-homelab:andrew_wu/project-note.git`) — not
  the homelab code repo itself.
- Note: `Homelab/2 - Specs/<issue>-<slug>.md`. `<issue>` is the Forgejo
  issue number on `andrew_wu/homelab`; `<slug>` is derived the same way
  `tmux-forgejo-picker.sh` derives it (lowercase the title, collapse
  non-alphanumeric runs to a single `-`, trim, cap at 40 chars). This must
  match byte-for-byte — it is also the branch name (`feature/<issue>-<slug>`)
  and the worktree dir name (`feature-<issue>-<slug>`), so issue, spec,
  branch, and worktree are all derivable from each other with no separate
  lookup table.
- Round snapshots: `Homelab/2 - Specs/.rounds/<issue>-<slug>/round-NN.md` —
  immutable per-round copies, `round-NN.md` == end-of-round-N state. Unlike
  MOP's vault (Obsidian Git auto-commits every ~65s, so git history can't
  serve as a round boundary), `project-note` only commits when told to — git
  history here *could* stand in for round boundaries. Snapshots are kept
  anyway, for one reason: `hl-pr-ready`'s drift gate needs to diff exactly
  round N-1 against round N, and an explicit snapshot is a more reliable
  boundary than "whichever commit I happened to make."

## Frontmatter fields

- `type` — always `spec` (lets a future Dataview query roll every spec up
  onto the project dashboard).
- `issue` — the Forgejo issue number, e.g. `12`.
- `created` — `YYYY-MM-DD`, set once at `hl-spec-init`.
- `round` — current round number. Bumped by `hl-spec-sync` each round.
- `posted` — list of publish records, one per `hl-spec-post` write. Each
  entry: `{round, date, url?, description}`. `url` is the issue-comment URL
  when a comment was posted; omitted for a description-only re-sync.
  `description` is `synced` or `resynced`. Shape only — see `hl-spec-post`
  for how the baseline round is chosen and when to write which value.

## Sections (in order)

1. `# [#<issue>] <title>` — title, plus `> Forgejo:` link line.
2. `## Spec` — see `hl-doc-spec-body` for what this contains.
3. `## Open Questions (private — curate before hl-spec-post)` — checkbox
   list, each item with `· evidence: path:line`.
4. `## Decision Log` — `| Date | Source | Decision |` table, append-only.
5. `## Round History` — `- **Round N** (date): summary`, append-only.

## Template

```markdown
---
type: spec
issue: <N>
created: <YYYY-MM-DD>
round: 1
posted: []
---
# [#<N>] <title>

> Forgejo: https://git.tailcb6113.ts.net/andrew_wu/homelab/issues/<N>

## Spec

### Goal / Motivation
…

### Components touched
- Compose service(s): …
- Caddy / tailnet node(s): …

### Config & secrets
- Env vars: …
- Ports: …
- Volumes: …

### Data model / storage
…

### Operational concerns
- Restart policy: …
- Resource limits: …
- Backups / monitoring: …

### Verification steps
- …

## Open Questions (private — curate before hl-spec-post)
- [ ] <question>  ·  evidence: `path:line`

## Decision Log
| Date | Source | Decision |
|------|--------|----------|
| <YYYY-MM-DD> | issue | Initial spec captured from issue #<N>. |

## Round History
- **Round 1** (<YYYY-MM-DD>): initial spec from Forgejo issue #<N>.
```
