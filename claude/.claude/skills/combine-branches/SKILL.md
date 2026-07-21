---
name: "combine-branches"
description: "Rebuild a disposable integration branch by merging several feature branches into one base, then optionally deploy it to Jenkins dev/uat as a single feature link. Use whenever the user wants to combine/merge multiple feature branches into one deployable branch, show several features under one deploy URL, build an integration branch, or 'combine branches MOP-X MOP-Y'."
---

# Combine Branches Skill

## Purpose

Show the combined result of several independent feature branches under **one**
deploy link, without disturbing their individual PRs. The integration branch is
disposable — recreated from scratch on every run — so it never drifts: it is
always `base` + the current tip of each feature branch. This is the git-native,
CI-visible equivalent of GitButler's local virtual-branch workspace.

## When to use

- The user is developing 2+ features on separate branches but needs a single
  deployed URL (Jenkins dev/uat) showing all of them together.
- The user asks to "combine", "merge into one branch to deploy", "integration
  branch", or "one link for these features".

## Underlying script

`~/bin/combine-branches.sh [options] <feature-branch>...`

Options:
- `-b, --base <branch>` — base to build on (default: `main`)
- `-n, --name <branch>` — integration branch name (default: `integration/combined`)
- `-d, --deploy` — run `deploy-one.sh` after a successful push
- `-l, --local` — merge local branches instead of `origin/<branch>` (default is
  origin refs after a fetch, matching what Jenkins actually builds)
- `-p, --no-push` — build locally only, do not push
- `-h, --help`

## Workflow

1. Confirm from the user:
   - the feature branches to combine,
   - the base branch (default `main`),
   - the integration branch name (suggest `integration/<epic>` when a ticket is known),
   - whether to deploy now (`-d`).
2. Run the script with the resolved arguments.
3. On **conflict**: the script aborts cleanly and names the culprit branch and
   files. Report those to the user — do not attempt an automatic resolution
   unless asked. The user resolves, then re-runs.
4. On **success**: report the combined branch SHA and, if deployed, that the
   dev/uat Jenkins jobs were triggered. Otherwise give the exact `deploy-one.sh`
   command to run.

## Notes

- Prerequisites for `-d` are the same as [deploy-one](../deploy-one/SKILL.md):
  VPN connected and `JENKINS_TOKEN` set.
- Re-run this skill after pushing to any feature branch to refresh the combined
  link. There is no incremental update — a full rebuild is the intended flow.
- The individual feature branches and their PRs are never modified.

## Example commands

```bash
# Combine three features and deploy the combined link
~/bin/combine-branches.sh -d -n integration/MOP-27675 \
  feature/MOP-27675 feature/MOP-27676 feature/MOP-27677

# Build a combined branch off a uat base without deploying
~/bin/combine-branches.sh -b uat/MOP-99 -n integration/demo feature/A feature/B
```
