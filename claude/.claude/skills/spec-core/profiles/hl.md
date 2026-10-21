# Profile: hl

Homelab infra issues on Forgejo. Spec notes are in `project-note`, not in
the homelab code repo.

## Identity and paths

- ID: the Forgejo issue number `<N>`. On a branch, `<N>` is the number in
  `feature/<N>-…`.
- `<id>`: the note file name without `.md`, `<N>-<slug>`. Find it by issue
  number: `ls "$SPECS"/<N>-*.md`. Do not make it from the branch name. The
  note slug and the branch slug can be different.
- `<slug>` (`spec-init` only): use the rule of `tmux-task-source-forgejo.sh`.
  Change the issue title to lowercase. Change each run of
  non-alphanumeric characters to one `-`. Trim. Keep 40 characters maximum.
- `SPECS` = `$HOME/personal/project-note/Homelab/2 - Specs`. Quote it: it
  has spaces.
- Vault-commit rule: after each note write, commit the note and each new
  snapshot in `~/personal/project-note`. Message:
  `spec: <step> #<N> <slug>, round N`.

## Tracker

- Channels: the Forgejo issue, chat.
- Access: `tea login list` shows a login for `<forgejo-host>`.
  `$FORGEJO_HOMELAB_REPO` is set in `~/.zshrc.local`. If it is not set,
  stop and tell the user.
- You: the repo owner, `${FORGEJO_HOMELAB_REPO%%/*}`. A comment is yours
  when its `author` is that name.
- Fetch: **inline**.
  ```bash
  tea issues <N> --comments -o json -r "$FORGEJO_HOMELAB_REPO"
  ```
  Read each image in a comment.
- Init extras: make `<slug>` from the issue title. For the init check, use
  `ls "$SPECS"/<N>-*.md`, not the new name.

## Grounding

- Repos: `~/homelab` (or a worktree of it), `~/personal/project-note`.
- Run: **inline**.
- Checks:
  1. **Similar service or pattern?** Search each `compose.yaml` and service
     directory for a pattern to use again: a Caddy block, a restart
     policy, an `.env.example` entry. Report each difference.
  2. **Missing details?** Find what the issue does not state: error
     handling, restart policy, resource limits.
  3. **Breaks existing behavior?** Find port conflicts, Tailscale node name
     conflicts, and shared network or volume conflicts.
  4. **New exposure?** Find each new Tailscale node and each ACL change.
     `caddy/compose.yaml` shows the node pattern.
  5. **Secrets?** For each new env var, check for an `.env.example` entry.
     Check that the `**/.env` gitignore rule covers it.
- Do not open a `.env` file. Read `.env.example` only. Report env var
  names, not values.

## Note language

English, for the note and the reports.

## Frontmatter (in addition to schema.md)

- `type` — `spec`.
- `issue` — the Forgejo issue number.

## Decision Log and Open Questions

- Source tags: `issue`, `chat`, `dev`.
- Waiting bucket: `waiting on external` (upstream docs, a vendor, a
  hardware test).
- Change reasons: `[spec change]`, `[misread]`, `[prior decision wrong]`,
  `[new info]`.
- Recommended reason: source `issue` → `[spec change]`. Source `chat` →
  `[new info]`.
- Replaces suffix: `, replaces YYYY-MM-DD "…"`.
- Round History reason count: `(2 spec change, 1 new info)`.

## Spec body

Heading: `## Spec`.

### Subsections

Write each subsection. If a subsection has no content, write `- none`.

- **Goal / Motivation** — one or two sentences: what this gives, and why
  now.
- **Components touched** — the compose services that you add or change,
  and the Caddy routes or Tailscale nodes. Use the service names from
  `compose.yaml`.
- **Config & secrets** — the names of new or changed env vars (and if each
  needs an `.env.example` entry), ports, volumes. Do not write secret
  values.
- **Data model / storage** — the data that you keep, the location (bind
  mount or named volume), and its structure.
- **Operational concerns** — restart policy, resource limits, `restic`
  backup of new paths, health and monitoring.
- **Verification steps** — steps that you can run: a curl to a health
  check, a log line to find, a manual test. Do not use
  Precondition/Action/Expected-Result blocks.

### Terms

- **Show**: compose service names, env var names, ports, repo paths. Do not
  show env var values.
- **Avoid**: line-by-line implementation plans, library choices.

### Challenge cross-references

- A service, env var, port, or volume in one subsection that is not in
  Components touched or Config & secrets.

## Post

- Body heading match (for `awk -v h=`): `## Spec`.
- Fetch and guards: **inline**. Save the issue first. Its `body` is the raw
  description (markdown):
  ```bash
  tea issues <N> --comments -o json -r "$FORGEJO_HOMELAB_REPO" > "$DRAFTS/issue.json"
  jq -r '.body' "$DRAFTS/issue.json" > "$DRAFTS/description.live"
  ```
- Own-author comments: yours (Tracker "You"). Comment header:
  `[Round N] Spec confirmation`.
- Archive command (after approval). Make sure that the archive comment is
  posted before you overwrite the description:
  ```bash
  { echo "**Original description (archived before spec-post overwrite, $(date +%F))**"; echo
    sed 's/^/> /' "$DRAFTS/description.live"; } > "$DRAFTS/archive.md"
  tea comments add <N> -r "$FORGEJO_HOMELAB_REPO" "$(cat "$DRAFTS/archive.md")"
  ```
- Postable rule: post each unchecked item.
- Stamp phrases: ``synced by `spec-post` ``, ``synced by `hl-spec-post` ``.
- Description: markdown in `$DRAFTS/description.md`.
  ```bash
  {
    echo "> **Round N · last updated $(date +%F)** — synced by \`spec-post\`;"
    echo "> full history in \`project-note/Homelab/2 - Specs/<id>.md\`."
    echo
    cat "$DRAFTS/spec.md"
  } > "$DRAFTS/description.md"
  ```
- Comment template: `$DRAFTS/comment.md`:
  ```markdown
  ## [Round N] Spec confirmation

  ### Open
  1. <question>
  ```
- Mention: none.
- Write commands:
  ```bash
  tea issues edit <N> -r "$FORGEJO_HOMELAB_REPO" --description "$(cat "$DRAFTS/description.md")"
  tea comments add <N> -r "$FORGEJO_HOMELAB_REPO" "$(cat "$DRAFTS/comment.md")"
  ```

## Drift

- Code repo: the homelab worktree on the `feature/<N>-…` branch. Run
  `git fetch origin main` first.
- Round-diff path (steps 2–4): **inline**.
- Change kinds: env var renamed, port changed, restart policy changed,
  volume path changed, compose service or Caddy route renamed.
- Search command:
  ```bash
  grep -rnIF -f "$VALUES" . --include='*.yaml' --include='*.yml' --include='*.ts' --include='*.env.example'
  ```
- One-round scan: **spec statements**.
  ```bash
  git diff origin/main...HEAD -- '*.yaml' '*.yml' '.env.example'
  ```
  For each fact that the spec states in Config & secrets, Data model,
  Operational concerns, or Verification steps (an env var, a port, a
  restart policy, a volume path), compare the diff:
  - The diff is different from the spec (for example, the spec says
    `restart: unless-stopped` and the diff sets `restart: no` or has no
    restart policy): **Contradiction**.
  - The diff does not include it yet: **Soft finding**.
  - The spec says nothing about it: do not report it.
- One-round Contradiction blocks the flip: **yes**.

## Ready

- PR CLI: `tea`.
- PR lookup: find the PR by its head branch. The PR number is not the issue
  number. Do not make the branch name from the note slug.
  ```bash
  tea pulls list --state all -f index,head,state,title,url -o json -r "$FORGEJO_HOMELAB_REPO" \
    | jq '[.[] | select(.head | startswith("feature/<N>-"))] | first'
  ```
  `<PR>` is its `index`. No match → no PR.
- PR view: `tea pulls <PR> -o json -r "$FORGEJO_HOMELAB_REPO"`. Draft
  signal: the title starts with `WIP:` or `[WIP]`. Do not add the prefix
  again.
- CI: `tea pulls <PR> -f ci -o json -r "$FORGEJO_HOMELAB_REPO"`.
- What CI does not run: the only workflow is
  `.forgejo/workflows/pr-gate.yml`. It runs `tsc` for `bookmark-webhook`
  and `download-service`, and `docker compose config` for each service.
  There is no test suite. A pass means that the code compiles and the
  compose files parse. It does not mean that the service works.
- Reviewers: **no**. No comment index, no bot requests.
- Extra gates: none.

### Gate 4: identifiers

- Pattern:
  ```bash
  git diff origin/main...HEAD | grep '^-' | grep -oE "[A-Z_][A-Z0-9_]*=|^\s*-?\s*[a-z0-9_-]+:"
  ```
- Add by hand: env var names, compose service, network, and volume names,
  Caddy hostnames and routes, and each name that a different service or
  script uses (`tmux-build-backend-forgejo.sh`,
  `tmux-task-source-forgejo.sh`, `README.md`).
- Search: **inline**, from the repo root, with the identifiers in a file
  (`ready.md` step 4): `grep -rnIF -f <file> .`

### Step 5: review

- Run: **inline**. Read the diff.
- Checklist:
  - **Compose services.** Check that the `restart:` policy agrees with the
    other services. Check that secrets come from `.env`. Check each port
    under `ports:`: it must stay internal behind Caddy and a Tailscale node
    when possible. Check that a new volume path is in the `**/data/`
    gitignore pattern.
  - **TypeScript services (`bookmark-webhook`, `download-service`).** Find
    promise rejections that nothing handles. Find new external HTTP calls
    with no error handling or retry. Find env vars that have no default and
    no check at startup.
    - **The value that arrives, not the type.** For a new field that the
      service writes to disk or sends: find its value when it is missing
      (`undefined`, `null`, or `''`). Check that the code that reads it
      expects that value.
  - **Caddy / Tailscale.** Find a new node name that is the same as an
    existing name. Find a new route in `caddy/compose.yaml` that has no
    Tailscale node of its own.
  - **Defects in a fix.** Find variables or imports that the fix left with
    no purpose.

### Flip

```bash
tea pulls edit <PR> -r "$FORGEJO_HOMELAB_REPO" --ready
```

Merge rule: do not merge. The user merges by hand. There is no CODEOWNERS.

## Flow

- Branch: the `wt` worktree (`feature/<N>-…`).
- `<base>`: `origin/main`.
- Commit count: `git rev-list --count origin/main..HEAD`.
- PR lookup: the PR lookup of the Ready section. No match → none. `state`
  `open` and a `WIP:` title → draft. `open` → ready. `merged` → merged.
  `closed` → closed.
- Pre-ready steps (row 10): none.
- Shipped check: the PR `state` is `merged`.
- Shipped action: none. Report that the issue is done.

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
