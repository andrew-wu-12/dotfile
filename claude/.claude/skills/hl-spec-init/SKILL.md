---
name: hl-spec-init
description: >-
  Create a persistent, codebase-grounded spec artifact for a homelab Forgejo
  issue, plus a private Open Questions list. Use when starting a new homelab
  issue, initializing a spec, opening the spec for issue #N, or "hl-spec-init
  #N". Use hl-spec-sync for later rounds.
---

# HL Spec Init → durable spec artifact

Turn a homelab Forgejo issue into a persistent, versioned spec note in
`project-note`. The note accumulates across rounds and grounds itself in the
actual homelab repo — not just the issue text.

`SKILL_DIR` = `~/.claude/skills/hl-spec-init`.

## Artifact schema

See `hl-doc-spec-schema` for the note's path, frontmatter fields, and
section structure.

## Prerequisites

- `tea` authenticated (`tea login list` shows a login for
  `git.tailcb6113.ts.net`).
- `~/homelab` (or a worktree of it) and `~/personal/project-note` both on
  disk.
- If `Homelab/2 - Specs/<issue>-<slug>.md` **already exists** in
  `project-note`, stop — this is a later round. Tell the user to run
  `hl-spec-sync` instead.

## Workflow

### 1. Fetch the issue

```bash
tea issues <N> --comments -o json -r andrew_wu/homelab
```

Read the title, body, and every comment. Derive `<slug>` the same way
`tmux-forgejo-picker.sh` does: lowercase the title, collapse non-alphanumeric
runs to a single `-`, trim, cap at 40 chars. This must match exactly — it is
also the branch name (`feature/<issue>-<slug>`) and worktree dir
(`feature-<issue>-<slug>`).

### 2. Ground in the codebase — the five checks

Run these against the real repo (`~/homelab`), each cited as `path:line`:

1. **Similar service/pattern already in repo?** Search each `compose.yaml`
   and existing service directory for something this issue should reuse or
   align with (an existing Caddy block shape, an existing service's restart
   policy, an existing `.env.example` pattern). Flag any divergence.
2. **Missing details?** Error handling, restart policy, resource limits the
   issue leaves unstated.
3. **Breaks existing functionality?** Port collisions, Tailscale-node name
   collisions, shared network/volume conflicts with an existing service.
4. **New exposure surface?** Does this open a new Tailscale node, or need
   ACL thought (check `caddy/compose.yaml` for the current per-service node
   pattern)?
5. **Secrets handling?** New env vars — do they need a `.env.example` entry,
   and are they covered by the repo's `**/.env` gitignore rule?

Give one finding per check, or state "none found." Support each finding
with `path:line` evidence only — no raw grep dumps. **No guessing**: if the
issue does not state something, record it as unstated in Open Questions;
never infer it.

### 3. Generate the consolidated spec

Write `## Spec` using `hl-doc-spec-body`'s conventions (English, subsection
shape, decision-log boundary). Use only concrete details from the issue and
the codebase. **Do not invent** config, ports, or behaviors — an unstated
value goes to Open Questions instead.

### 4. Assemble Open Questions (private)

Every gap from step 2 becomes a checkbox with its `path:line` evidence. This
list stays private until curated in `hl-spec-post`.

### 5. Write the note, then snapshot

Write `Homelab/2 - Specs/<issue>-<slug>.md` in `project-note` using
`hl-doc-spec-schema`'s template, then:

```bash
~/bin/hl-spec-snapshot.sh <issue>-<slug>   # creates round-01
cd ~/personal/project-note
git add "Homelab/2 - Specs/<issue>-<slug>.md" "Homelab/2 - Specs/.rounds/<issue>-<slug>/round-01.md"
git commit -m "spec: init #<issue> <slug>, round 1"
```

Run the snapshot **last** — after the note is written — so `round-01.md`
matches the end-of-round-1 state.

### 6. Report

List, in English:
- Open Questions list
- Cross-source conflicts (issue text vs. what's actually in the repo)
