---
name: create-deploy-plan
description: >-
  Create a deploy plan page in Confluence (MOP space) for the epic of the current
  git branch, following the MOP deploy plan template. Use this whenever the user
  asks to create/generate a deploy plan, write up a release/deployment plan, make
  a deploy plan page, prepare a deployment doc for a ticket, or "deploy plan for
  MOP-XXXX" — even if they don't say "Confluence" explicitly. Scaffolds the page
  (pre-publish checklist, per-stage one-dev/one-uat/one deploy checklists, Tickets
  macro, Deployments table) under the dated deploy-YYYYMMDD folder; the operational
  cells are filled by hand in the browser.
---

# Deploy Plan → Confluence

Turn the epic behind the current branch into a Confluence **deploy plan** page in
the MOP space, matching the MOP deploy plan template (see the reference example
`[MOP-27811] Task Mgmt. - Update API Host for Datalake Phase Out`).

This is a **scaffolding** skill, not an auto-detector. The template's structure,
title, ticket link, and correct parent folder are the fiddly deterministic parts
and are handled here; the operational details (which git projects/versions get
deployed, who executes, deploy start/end times) are only known at deploy time and
are left as the template's placeholder row for the user to fill in the browser.

`SKILL_DIR` below = `~/.claude/skills/create-deploy-plan`.

## Prerequisites

- Run from **inside the working tree whose branch names the ticket** (usually the
  monorepo, `$MOP_MONOREPO_PATH`) — "current branch" means that repo's checked-out
  branch. Or pass an explicit `MOP-XXXX`.
- **VPN connected** and `JIRA_TOKEN` in the environment (`source ~/.zshrc`). The
  same token authenticates both Jira and Confluence.

## Workflow

### 1. Resolve the epic and deploy date

```bash
"$SKILL_DIR/scripts/resolve_epic.sh" [MOP-XXXX]
```

With no argument it parses the ticket from the current branch
(`feature/MOP-XXXX`, `hotfix/MOP-XXXX`, ...). It then walks up the parent chain to
the first **Epic** and returns:

- `epic_key` / `epic_summary` — the deploy plan's subject. If no Epic is reached
  before a null parent (or the initiative `MOP-24745`), the top-most node reached
  is used and `epic_found` is `false`. This is normal — standalone Production
  Support / Task tickets like MOP-27811 have no epic and *are* the subject.
- `deploy_date` — PM Release Date (`10379`) preferred over Expected Due Date
  (`10329`), checked on the branch ticket first, then up the chain. `null` if none
  resolved — **ask the user for the deploy date** in that case.

Show the user the resolved subject and deploy date. If `epic_found` is `false` and
the branch ticket clearly *should* sit under an epic, let the user override the
ticket rather than plan against the wrong subject.

### 2. Locate the parent deploy-YYYYMMDD folder

```bash
"$SKILL_DIR/scripts/find_deploy_parent.sh" <YYYYMMDD>   # date from step 1
```

The dated deploy nodes are Confluence **folders** (not pages), so this uses CQL —
a plain title lookup would miss them. A page can be parented under a folder, so
the returned `id` is used directly as the ancestor when publishing.

- **found** → use its `id` as the parent.
- **not_found** (exit 2) → **stop and ask the user**. Do NOT auto-create the
  dated folders — the folder hierarchy (`deploy-YYYY` / `deploy-YYYYMM` /
  `deploy-YYYYMMDD`) is release-owned and the correct parent may be a different
  date than the ticket's field suggests. Ask the user to create the folder (or
  point you at the right existing one) and re-run with its date/id.

### 3. Ask the two prod-stage questions, then build the body

Every deploy plan is a frontend `mop-console-monorepo` deploy through three
environment stages (one-dev → one-uat → one), so that scaffold is fixed. Only the
prod stage (`one`) varies, by two independent steps — **ask the user both**:

- **Backend publish needed?** → `--be-publish`
- **Config file changes to deploy?** → `--config-deploy`

A deploy can need either, both, or neither (config changes without a BE publish is
common), so keep them separate. Then generate the body:

```bash
"$SKILL_DIR/scripts/build_body.py" <epic_key> [--be-publish] [--config-deploy] > /tmp/body.xml
```

What the generator produces (don't hand-edit the storage XML — change
`build_body.py` if the template itself needs to evolve):

- **Pre-publish checklist** — two standard tasks (Dry Run Plan with BA/SA ·
  SA - Check Jira Status), left **incomplete**.
- **one-dev / one-uat** — each: Deploy `mop-console-monorepo` to <env> · Test
  module in `mop-console-monorepo` (Affected APPs).
- **one** — optional `BE - Publish` and `Deploy mop_configuration_files to one`
  (per the flags) first, then Deploy `mop-console-monorepo` to one · Test module.
- **Tickets** — the epic macro only.
- **Deployments** — header + grey guidance row + a pre-filled `mop-console-monorepo`
  data row (other cells blank, filled at deploy time). With `--config-deploy`, a
  second `mop_configuration_files` row is added.

**Title**: `[<epic_key>] <epic_summary>` — e.g.
`[MOP-27811] Task Mgmt. - Update API Host for Datalake Phase Out`.

**Show the user the title, parent folder, and the two flag answers, then get one
explicit confirmation** before publishing. You can dry-run without posting:

```bash
DRY_RUN=1 "$SKILL_DIR/scripts/publish_page.sh" "<title>" /tmp/body.xml <parent_id>
```

### 4. Publish

```bash
"$SKILL_DIR/scripts/publish_page.sh" "<title>" <body_file> <parent_id>
```

Defaults to space `MOP`. If it exits `2` (`status:exists`), a same-title deploy
plan already exists — **stop, show the user its URL, and don't overwrite.** On
success, report the new page's URL and remind the user to fill the Deployments
table (version / developer / executor — the git project is pre-filled) and work
through the per-stage checklists in the browser.
