---
name: "trace-build"
description: "trace Jenkins builds for a branch and monitor their status until completion using the trace-build script. Use this whenever the user asks to check build status, trace a branch build, monitor Jenkins builds, or see whether a branch build passed or failed."
---

# Build Trace Skill

## Purpose:

Finds recent Jenkins builds for a specified branch and monitors them until they finish.

## Features:

1. Accepts a required branch name.
2. Runs the `bin/trace-build.sh <branch>` script to search and trace builds.
3. Requires `JENKINS_TOKEN` to be available in the shell environment.
4. Searches these Jenkins jobs for builds matching the branch:
   - `mop_console_bulild_by_feature`
   - `mop_console_bulild_by_epic_or_hotfix`
   - `mop_console_monorepo_feature`
   - `mop_console_monorepo_epic_or_hotfix`
5. Reports running progress and final build results for all matched jobs.
6. Surfaces common failure cases clearly, such as missing branch name, missing Jenkins credentials, or no recent builds found.

## Workflow:

1. Confirm the branch name from the user request.
2. Execute `bin/trace-build.sh <branch>`.
3. Return the trace result:
   - **Success:** Report the matched Jenkins jobs and their final statuses.
   - **Failure:** Return the script error and suggest the likely fix, such as providing a branch name, checking Jenkins credentials, or verifying that a recent build exists for that branch.

## Example Command:

```bash
bin/trace-build.sh feature/my-branch
```
