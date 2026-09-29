---
name: privilege-node
description: >-
  Resolve the mop-configuration privilege node(s) a feature needs, ENV-aware:
  check dev/uat/master, promote the authoritative dev node or (only if absent
  everywhere) derive a new one from monorepo usage, then hand off to
  checkout-config.sh for the [DEV] PR. Use when a spec/ticket needs a privilege, a
  feature is hidden/403 because its permissionId isn't in the config repo, or
  "privilege-node MOP-XXXX". Pairs with the spec-init privilege gap check.
---

# Privilege Node → mop-configuration (env-aware)

Make sure the privilege ids a feature references actually exist in the right
`mop_configuration_files` environment branch. The config repo is
**branch-per-environment** (`dev` / `uat` / `master`) and dev gets configs first,
so the usual situation is *"the node exists in dev but hasn't been promoted"* —
not *"the node is missing"*. This skill distinguishes those and never re-derives a
node dev already defines.

`SKILL_DIR` = `~/.claude/skills/privilege-node`.

## Prerequisites

- Repos on disk: `$MOP_CONFIGURATION_PATH`, `$MOP_MONOREPO_PATH`.
- Network/VPN (the gather script fetches origin).

## Workflow

### 1. Identify the privilege id prefix

From the spec note's privilege Open Question (`specs/MOP-XXXX.md`) or the code:

```bash
grep -rn "permissionId\|useCheckPermission\|_PERMISSION_ID" \
  "$MOP_MONOREPO_PATH/apps/<app>" --include='*.ts' --include='*.tsx' | grep <feature>
```

Settle on the dotted prefix, e.g. `tms_mgmt.trucker_portal`.

### 2. Gather env-aware state

```bash
"$SKILL_DIR/scripts/gather_privilege.sh" tms_mgmt.trucker_portal
```

It fetches origin and reports presence in `dev` / `uat` / `master`, then branches:

- **Present in dev** → prints the **verbatim dev node** (source of truth) and a
  verdict (promotion needed, or nothing to do).
- **Absent in dev** → prints the insertion parent, a sibling template, and the
  monorepo route/action usage needed to derive a new node.

### 3. Act on the verdict

**Case A — node exists in dev (the common case):**
Do **not** derive or edit anything by hand. The dev node is authoritative (it may
carry children/flags you would not reproduce — e.g. a `sync_data` leaf, or
`has_policy: false`). If it's missing in uat/master, the gap is **promotion**,
which rides the standard `dev → uat → master` config PRs (opened by hand, since
they carry every pending dev change, not just this node). Report to the user:
which envs have it, which don't, and that promotion is the action — not creation.
Only edit a specific env branch directly if the user explicitly wants this node
promoted out-of-band ahead of the normal flow; if so, copy the dev node
**verbatim** into that branch's `privileges.json`.

**Case B — node absent in every env:**
Derive a new node and insert it into `dev`.
- Mirror the sibling template. An id that appears as a `route.ts` **page route** →
  the menu node gets `"menu": true` + `"url"` (derive from the route `path`,
  matching the sibling's url style). An id used only in an **action check**
  (`useCheckPermission`, a query/edit/sync permissionId) → an `"api": true` leaf
  `{ id, name, api: true }`. Copy `has_policy`/`show_policy_attribute` from the
  sibling **only if** the feature actually needs a policy — do not assume.
- Show the user the derived JSON and resolved url; ask on any ambiguity.

### 4. Insert into privileges.json (Case B only — minimal diff)

**Edit surgically — never reformat.** `privileges.json` is not a clean `json.dumps`
round-trip (inline arrays like `["company"]`), so a full re-dump makes a huge noise
diff. Use the Edit tool to insert only the new node into the insertion parent's
`children` array. Get the two nested-JSON hazards right:
- **Trailing comma:** the current last child has no comma before `]`; add one after
  it, then append the new node.
- **Indentation:** match siblings exactly.

Validate and confirm the diff is only the inserted lines:

```bash
python3 -m json.tool "$MOP_CONFIGURATION_PATH/privileges.json" >/dev/null \
  && echo "valid JSON" || echo "INVALID — fix before continuing"
git -C "$MOP_CONFIGURATION_PATH" diff -- privileges.json
```

### 5. Hand off to the [DEV] PR (Case B, or an explicit out-of-band promote)

```bash
~/bin/checkout-config.sh MOP-XXXX
```

Stashes the edit, bases `feature/MOP-XXXX` on latest `dev`, commits, pushes, opens
the `[DEV]` draft PR. Remind the user that uat/master promotion PRs stay hand-made.

## Rules

- Check all three env branches first — "missing" is usually "not promoted".
- dev is the source of truth: promote verbatim, never re-derive over it.
- Case B derives only what usage proves (route vs. action); don't assume policies.
- Minimal, valid-JSON diff; confirm with the user before editing or PRing.
