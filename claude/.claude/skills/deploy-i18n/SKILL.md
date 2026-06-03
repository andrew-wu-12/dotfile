---
name: "deploy-i18n"
description: "deploy i18n, translations, or locale changes to dev, uat, or prod using the Jenkins i18n deploy script. Use this whenever the user asks to run an i18n deployment, translation deployment, locale deploy, or Jenkins i18n deploy."
---

# I18n Deployment Skill

## Purpose:

Deploys i18n resources to the target environment through the Jenkins job used by the local deploy script.

## Features:

1. Accepts a target environment: `dev`, `uat`, or `prod`.
2. Runs the `bin/deploy-i18n.sh <env>` script to trigger the Jenkins deployment.
3. Checks for common prerequisites before deployment:
   - VPN connection is active.
   - `JENKINS_TOKEN` is available in the shell environment.
4. Reports command output and surfaces common failure cases clearly.

## Workflow:

1. Confirm the target environment from the user request.
2. Validate that the environment is one of: `dev`, `uat`, `prod`.
3. Execute `bin/deploy-i18n.sh <env>`.
4. Return the deployment result:
   - **Success:** Report that the Jenkins deploy was triggered for the requested environment.
   - **Failure:** Return the script error and suggest the likely fix, such as connecting VPN or checking Jenkins credentials.

## Example Command:

```bash
bin/deploy-i18n.sh dev
```
