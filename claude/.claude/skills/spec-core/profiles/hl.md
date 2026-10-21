# Profile: hl

Homelab infra issues on Forgejo (`$FORGEJO_HOMELAB_REPO`, set in
`~/.zshrc.local`). Spec notes live in `project-note`, a git submodule of the
main Obsidian vault — not in the homelab code repo.

## Identity and paths

- ID: Forgejo issue number `<N>`. `<id>` == `<N>-<slug>`.
- `<slug>`: derive it the same way `tmux-task-source-forgejo.sh` does —
  lowercase the issue title, collapse non-alphanumeric runs to a single `-`,
  trim, cap at 40 chars. It must match byte-for-byte: it is also the branch
  name (`feature/<N>-<slug>`) and the worktree dir (`feature-<N>-<slug>`).
- `SPECS` = `$HOME/personal/project-note/Homelab/2 - Specs` (quote it — it
  has spaces).
- Vault commits: `project-note` commits only when told to. After every note
  write, commit the note (and any new snapshot) in `~/personal/project-note`
  with `spec: <step> #<N> <slug>, round N`.

## Tracker

- Channels: the Forgejo issue, and chat/verbal discussion.
- Access: `tea` authenticated (`tea login list` shows a login for
  `<forgejo-host>`).
- Fetch: **inline**.
  ```bash
  tea issues <N> --comments -o json -r "$FORGEJO_HOMELAB_REPO"
  ```
  An image in a comment is rare (e.g. an error screenshot); read it directly.
- Init extras: derive `<slug>` from the issue title (see Identity and paths).

## Grounding

- Repos: `~/homelab` (or a worktree of it), `~/personal/project-note`.
- Run: **inline** — the repo is small.
- Checks:
  1. **Similar service/pattern already in repo?** Search each
     `compose.yaml` and service directory for something to reuse or align
     with (a Caddy block shape, a restart policy, an `.env.example`
     pattern). Flag any divergence.
  2. **Missing details?** Error handling, restart policy, resource limits
     the issue leaves unstated.
  3. **Breaks existing functionality?** Port collisions, Tailscale-node name
     collisions, shared network/volume conflicts.
  4. **New exposure surface?** A new Tailscale node, or ACL thought needed
     (see `caddy/compose.yaml` for the per-service node pattern).
  5. **Secrets handling?** New env vars — do they need a `.env.example`
     entry, and does the repo's `**/.env` gitignore rule cover them?

## Note language

English, for the note and the reports.

## Frontmatter (in addition to schema.md's)

- `type` — always `spec`.
- `issue` — the Forgejo issue number.

## Decision Log and Open Questions

- Source tags: `issue`, `chat`, `dev`.
- Waiting bucket: `waiting on external` (upstream docs, a vendor, a
  hardware test — something outside your control).
- Change reasons: `[spec change]`, `[misread]`, `[prior decision wrong]`,
  `[new info]`.
- Recommended reason by source: `issue` → `[spec change]`; `chat` →
  `[new info]`.
- Replaces suffix: `, replaces YYYY-MM-DD "…"`.
- Round History reason count, e.g. `(2 spec change, 1 new info)`.

## Spec body

Heading: `## Spec`.

### Subsections

Write every subsection. If one has nothing to say yet, write `- none` — an
omitted heading reads as "forgot to check", not "checked, N/A".

- **Goal / Motivation** — one or two sentences: what this unlocks, why now.
- **Components touched** — compose service(s) added or changed, Caddy
  routes or Tailscale nodes involved. Real service names from
  `compose.yaml`.
- **Config & secrets** — new or changed env vars (and whether each needs a
  `.env.example` entry), ports, volumes.
- **Data model / storage** — what gets persisted, where (bind mount vs named
  volume), and its shape if structured.
- **Operational concerns** — restart policy, resource limits, whether
  `restic` backup coverage extends to a new path, health/monitoring.
- **Verification steps** — concrete and runnable: a curl against a
  healthcheck, a log line to grep for, a manual click-through. No
  Precondition/Action/Expected-Result blocks.

### Terms

- **Show**: real compose service names, env var names, ports, repo paths.
- **Avoid**: line-by-line implementation plans and library choices.

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

> Forgejo: https://<forgejo-host>/<$FORGEJO_HOMELAB_REPO>/issues/<N>

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

## Open Questions (private — curate before spec-post)
- [ ] <question>  ·  evidence: `path:line`

## Decision Log
| Date | Source | Decision |
|------|--------|----------|
| <YYYY-MM-DD> | issue | Initial spec captured from issue #<N>. |

## Round History
- **Round 1** (<YYYY-MM-DD>): initial spec from Forgejo issue #<N>.
```
