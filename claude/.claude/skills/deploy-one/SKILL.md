---
name: "deploy-one"
description: "deploy a branch to the dev and uat Jenkins monorepo jobs using the deploy-one script. Use this whenever the user asks to deploy a branch, run deploy one, trigger Jenkins deploy for a branch, or deploy the monorepo to dev and uat."
---

# Branch Deployment Skill

## Purpose:

Deploys a specified branch to the Jenkins monorepo deployment jobs for both dev and uat.

## Features:

1. Accepts a required branch name.
2. Runs the `bin/deploy-one.sh <branch>` script to trigger deployment jobs.
3. Checks for common prerequisites before deployment:
   - VPN connection is active.
   - `JENKINS_TOKEN` is available in the shell environment.
4. Triggers both Jenkins jobs:
   - `mop_console_monorepo_uat`
   - `mop_console_monorepo_dev`
5. Reports command output and surfaces common failure cases clearly.

## Workflow:

1. Confirm the branch name from the user request.
2. Execute `bin/deploy-one.sh <branch>`.
3. Return the deployment result:
   - **Success:** Report that the Jenkins deploy jobs for dev and uat were triggered for the requested branch.
   - **Failure:** Return the script error and suggest the likely fix, such as connecting VPN, checking Jenkins credentials, or verifying the branch name.

## Example Command:

```bash
bin/deploy-one.sh feature/my-branch
```
