# Profile: hl

Homelab infra issues on Forgejo (`$FORGEJO_HOMELAB_REPO`, set in
`~/.zshrc.local`). Spec notes live in `project-note`, a git submodule of the
main Obsidian vault — not in the homelab code repo.

## Identity and paths

- ID: Forgejo issue number `<N>`. From a branch, `<N>` is the number in
  `feature/<N>-…`.
- `<id>` is the note's file name without `.md`, `<N>-<slug>`. **Find it by
  issue number**: `ls "$SPECS"/<N>-*.md`. Never rebuild it from the branch
  name — the note slug and the branch slug can differ (issue 7: note
  `7-apple-reminders-via-radicale-caldav`, branch `feature/7-radicale-caldav`).
- Only `spec-init` (no note yet) derives `<slug>`, the same way
  `tmux-task-source-forgejo.sh` does: lowercase the issue title, collapse
  non-alphanumeric runs to a single `-`, trim, cap at 40 chars.
- `SPECS` = `$HOME/personal/project-note/Homelab/2 - Specs` (quote it — it
  has spaces).
- Vault commits: `project-note` commits only when told to. After every note
  write, commit the note (and any new snapshot) in `~/personal/project-note`
  with `spec: <step> #<N> <slug>, round N`.

## Tracker

- Channels: the Forgejo issue, and chat/verbal discussion.
- Access: `tea` authenticated (`tea login list` shows a login for
  `<forgejo-host>`), and `$FORGEJO_HOMELAB_REPO` set (in
  `~/.zshrc.local`). If it is unset, stop and say so.
- You: the repo owner, `${FORGEJO_HOMELAB_REPO%%/*}`. A comment is yours
  when its `author` equals that.
- Fetch: **inline**.
  ```bash
  tea issues <N> --comments -o json -r "$FORGEJO_HOMELAB_REPO"
  ```
  An image in a comment is rare (e.g. an error screenshot); read it directly.
- Init extras: derive `<slug>` from the issue title (see Identity and paths).
  The init existence check is `ls "$SPECS"/<N>-*.md`, not the derived name.

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
- Never open a `.env` file (real secrets live there); read `.env.example`
  only. Report env var names, never values.

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
- **Config & secrets** — new or changed env var **names** (and whether
  each needs a `.env.example` entry), ports, volumes. Never a secret value:
  this section is published to the Forgejo issue.
- **Data model / storage** — what gets persisted, where (bind mount vs named
  volume), and its shape if structured.
- **Operational concerns** — restart policy, resource limits, whether
  `restic` backup coverage extends to a new path, health/monitoring.
- **Verification steps** — concrete and runnable: a curl against a
  healthcheck, a log line to grep for, a manual click-through. No
  Precondition/Action/Expected-Result blocks.

### Terms

- **Show**: real compose service names, env var names, ports, repo paths.
  Never env var values.
- **Avoid**: line-by-line implementation plans and library choices.

### Challenge cross-references

- A service, env var, port, or volume named in one subsection but missing
  from Components touched or Config & secrets.

## Post

- Body heading match (for `awk -v h=`): `## Spec`.
- Fetch and guards: **inline**. The issue JSON from the Tracker fetch has
  the comments; its `body` is the raw live description (markdown). Save it
  before anything else:
  ```bash
  tea issues <N> --comments -o json -r "$FORGEJO_HOMELAB_REPO" > "$DRAFTS/issue.json"
  jq -r '.body' "$DRAFTS/issue.json" > "$DRAFTS/description.live"
  ```
- Own-author comments: yours (Tracker "You"). Header to match:
  `[Round N] Spec confirmation`.
- Archive foreign description (after approval). Check the archive comment
  posted before you overwrite:
  ```bash
  { echo "**Original description (archived before spec-post overwrite, $(date +%F))**"; echo
    sed 's/^/> /' "$DRAFTS/description.live"; } > "$DRAFTS/archive.md"
  tea comments add <N> -r "$FORGEJO_HOMELAB_REPO" "$(cat "$DRAFTS/archive.md")"
  ```
- Postable questions: every unchecked item. The issue is your own record;
  nothing in it is private from you.
- Stamp phrases (guard 1): ``synced by `spec-post` `` and, on issues posted
  before the merge, ``synced by `hl-spec-post` ``.
- Description: markdown in `$DRAFTS/description.md`.
  ```bash
  {
    echo "> **Round N · last updated $(date +%F)** — synced by \`spec-post\`;"
    echo "> full history in \`project-note/Homelab/2 - Specs/<id>.md\`."
    echo
    cat "$DRAFTS/spec.md"
  } > "$DRAFTS/description.md"
  ```
- Comment: `$DRAFTS/comment.md`:
  ```markdown
  ## [Round N] Spec confirmation

  ### Open
  1. <question>
  ```
- Mention: none.
- Writes:
  ```bash
  tea issues edit <N> -r "$FORGEJO_HOMELAB_REPO" --description "$(cat "$DRAFTS/description.md")"
  tea comments add <N> -r "$FORGEJO_HOMELAB_REPO" "$(cat "$DRAFTS/comment.md")"
  ```

## Drift

- Code repo: the homelab worktree on the issue's `feature/<N>-…` branch.
  Run `git fetch origin main` first — a stale `main` bloats the diff.
- Round-diff path (steps 2–4): **inline**.
- Change kinds: env var renamed, port changed, restart policy changed,
  volume path changed, compose-service or Caddy-route name changed.
- Search command:
  ```bash
  grep -rnIF -f "$VALUES" . --include='*.yaml' --include='*.yml' --include='*.ts' --include='*.env.example'
  ```
- One-round scan: **spec promises**.
  ```bash
  git diff origin/main...HEAD -- '*.yaml' '*.yml' '.env.example'
  ```
  For each concrete, checkable fact the spec's Config & secrets, Data model,
  Operational concerns, and Verification steps state (an env var, a port, a
  restart policy, a volume path), check whether the diff delivers it:
  - the diff **contradicts** an explicit statement (spec says
    `restart: unless-stopped`, diff sets `restart: no` or omits it) →
    **Contradiction**;
  - the diff has not got to it yet (an intentionally partial PR) → **Soft
    finding** (not delivered yet);
  - the spec is silent on something the diff does → not this check's
    concern.
- One-round Contradiction blocks the flip: **yes**.

## Ready

- PR CLI: `tea`.
- PR lookup: PR numbers are separate from issue numbers, so find the PR by
  its head branch — never use the issue number `<N>` as the PR number, and
  never rebuild the branch from the note slug:
  ```bash
  tea pulls list --state all -f index,head,state,title,url -o json -r "$FORGEJO_HOMELAB_REPO" \
    | jq '[.[] | select(.head | startswith("feature/<N>-"))] | first'
  ```
  `<PR>` = its `index`. No match → no PR.
- PR view: `tea pulls <PR> -o json -r "$FORGEJO_HOMELAB_REPO"`. Draft
  signal: a `WIP:` or `[WIP]` title prefix (Forgejo has no draft boolean).
  Never re-add the prefix.
- CI: `tea pulls <PR> -f ci -o json -r "$FORGEJO_HOMELAB_REPO"`.
- What CI does not run (last confirmed): the only workflow is
  `.forgejo/workflows/pr-gate.yml` — `tsc` for `bookmark-webhook` and
  `download-service`, and `docker compose config` for every service. **No
  test suite exists and nothing runs at runtime**: green means "type-checks
  and the compose files parse", not "the service works".
- Reviewers: **no** — you are the only reviewer. No comment index, no bot
  requests.
- Extra gates: none.

### Gate 4: identifiers

- Pattern:
  ```bash
  git diff origin/main...HEAD | grep '^-' | grep -oE "[A-Z_][A-Z0-9_]*=|^\s*-?\s*[a-z0-9_-]+:"
  ```
- By hand: env var names, compose service/network/volume names, Caddy
  hostnames/routes, and anything another service or script
  (`tmux-build-backend-forgejo.sh`, `tmux-task-source-forgejo.sh`,
  `README.md`) references by name.
- Search: **inline**, from the repo root, with the identifiers in a file
  (see `ready.md` step 4): `grep -rnIF -f <file> .`

### Step 5: review

- Run: **inline** — read the diff directly; the repo is small enough.
- Checklist:
  - **Compose service basics.** A `restart:` policy consistent with its
    neighbors? Secrets read from `.env`, not hardcoded? A port published
    under `ports:` that should stay internal behind Caddy + a Tailscale
    node? A new volume path under the `**/data/` gitignore pattern, or will
    it get committed?
  - **TypeScript services (`bookmark-webhook`, `download-service`).**
    Unhandled promise rejections on new async calls. Missing error
    handling/retry around a new external HTTP call (this repo has hit it
    before — see the "add retry" commits). An env var read with no default
    and no startup validation, failing at request time instead of boot.
    - **The value that arrives, not the type.** For a new field written to
      disk or sent in a request: is it `undefined`, `null`, or `''` when
      missing, and does downstream code assume another?
  - **Caddy / Tailscale.** A new node name colliding with an existing one.
    A route added to `caddy/compose.yaml` without its own Tailscale node,
    against the one-node-per-service pattern.
  - **New defects inside a correction.** Does a fix leave a dead variable
    or an unused import behind?

### Flip

```bash
tea pulls edit <PR> -r "$FORGEJO_HOMELAB_REPO" --ready
```

Merge rule: **never merge.** You review the final diff and merge by hand —
that click is the deliberate checkpoint. There is no CODEOWNERS.

## Flow

- Branch: the worktree from `wt` (`feature/<N>-…`).
- `<base>`: `origin/main`.
- Commit count: `git rev-list --count origin/main..HEAD`.
- PR lookup: the Ready section's lookup. No match → none; `state` `open`
  plus a `WIP:` title → draft; `open` → ready; `merged` → merged; `closed` →
  closed.
- Pre-ready steps (row 10): none.
- Shipped check: the PR `state` is `merged`.
- Shipped action: none — there is no docs step. Report the issue as done.

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
