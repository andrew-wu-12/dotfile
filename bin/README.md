# Development Utility Scripts

A collection of shell scripts for automating development workflows, JIRA integration, and Jenkins deployments for the MOP Console project.

## Prerequisites

- **GitHub CLI (`gh`)**: For PR management
- **jq**: For JSON parsing
- **curl**: For API requests
- **git**: Version control

### Environment Variables

Set these environment variables in your shell configuration:

```bash
export JIRA_TOKEN="your-email@example.com:your-jira-api-token"
export JENKINS_TOKEN="username:jenkins-api-token"
```

## Scripts Overview

### 1. `bi-weekly-report.sh`

Generates a bi-weekly report of your GitHub pull requests.

**Usage:**

```bash
./bi-weekly-report.sh
```

**What it does:**

- Fetches open PRs assigned to you
- Fetches closed PRs from the last 14 days
- Combines the data into JSON format
- Copies the report to your clipboard

**Output:**

```json
{
  "on_going": [...],
  "closed": [...]
}
```

---

### 2. `checkout-ticket.sh`

Automates the workflow for checking out a JIRA ticket, creating branches, and setting up pull requests.

**Usage:**

```bash
./checkout-ticket.sh MOP-12345
```

**What it does:**

1. Fetches ticket details from JIRA
2. Determines if it's a Production Support ticket or regular feature
3. Creates appropriate branches:
   - **Production Support**: Creates `hotfix/MOP-XXXXX` branch from `main`
   - **Regular Feature**: Creates `uat/MOP-XXXXX` (UAT) and `feature/MOP-XXXXX` (dev) branches
4. Creates draft PRs with pre-filled templates including:
   - Quality checklist
   - Related JIRA ticket links
   - Feature preview URLs
5. Triggers console deployment automatically

**Branch Naming Convention:**

- `hotfix/MOP-XXXXX` - Production hotfixes
- `uat/MOP-XXXXX` - UAT environment branches
- `feature/MOP-XXXXX` - Development branches

**PR Template Includes:**

- References to JIRA ticket
- Feature preview link
- Quality checklist
- Release date section
- Screenshot section

---

### 3. `checkout-config.sh`

Creates configuration PRs across multiple environments (dev, uat, prod).

**Usage:**

```bash
./checkout-config.sh MOP-12345
```

**What it does:**

1. Stashes current configuration changes
2. Creates branches for each environment:
   - `feature/MOP-XXXXX-dev`
   - `feature/MOP-XXXXX-uat`
   - `feature/MOP-XXXXX-prod`
3. Creates draft PRs targeting appropriate base branches:
   - dev → `dev`
   - uat → `uat`
   - prod → `master`
4. Applies stashed configuration to each branch

**Note:** Currently has syntax errors in the loop condition that need fixing.

---

### 4. `deploy-console.sh`

Deploys the MOP Console to Jenkins-based environments.

**Usage:**

```bash
# Basic deployment
./deploy-console.sh feature/MOP-12345

# Override environment
./deploy-console.sh feature/MOP-12345 uat
```

**Parameters:**

- `$1`: Branch name (required)
- `$2`: Override environment - `feature` or `uat` (optional)

**What it does:**

1. Determines target environment from branch name
2. Creates corresponding branch in `mop_console` repository
3. Triggers Jenkins job based on environment:
   - **feature** → `mop_console_bulild_by_feature`
   - **uat/hotfix** → `mop_console_bulild_by_epic_or_hotfix`
4. Passes branch and ticket information to Jenkins

**Jenkins Parameters:**

- `CORE_BRANCH`: Target branch name
- `SUBMODULE`: Always set to "core"
- `EPIC_TYPE`: Environment type (feature/uat)
- `JIRA_TICKET_TYPE`: Always "MOP"
- `JIRA_TICKET_NUMBER`: Extracted ticket number

---

### 5. `deploy-one.sh`

Deploys the MOP Console Monorepo to both dev and UAT environments simultaneously.

**Usage:**

```bash
./deploy-one.sh feature/MOP-12345
```

**What it does:**

1. Triggers parallel deployments to:
   - `mop_console_monorepo_dev`
   - `mop_console_monorepo_uat`
2. Passes the branch name to both Jenkins jobs

**Use Case:** Quick deployment when you want to update both environments at once.

---

### 6. `deploy-i18n.sh`

Deploys internationalization (i18n) updates to a specific environment.

**Usage:**

```bash
./deploy-i18n.sh dev   # Deploy to dev
./deploy-i18n.sh uat   # Deploy to UAT
./deploy-i18n.sh prod  # Deploy to production
```

**What it does:**

- Triggers the `mop_console_i18n_with_version` Jenkins job
- Deploys translation files to the specified environment

**Available Environments:**

- `dev` - Development environment
- `uat` - User Acceptance Testing environment
- `prod` - Production environment

---

## Workflow Examples

### Starting Work on a New Feature Ticket

```bash
# 1. Check out the ticket (creates branches and PRs)
./checkout-ticket.sh MOP-12345

# 2. The script automatically deploys to console
# (No manual deployment needed)

# 3. After making code changes, deploy updates if needed
./deploy-one.sh feature/MOP-12345
```

### Configuration Changes Across Environments

```bash
# 1. Make your configuration changes locally
vim config/app.config.js

# 2. Create PRs for all environments
./checkout-config.sh MOP-12345

# This creates 3 PRs (dev, uat, prod) with your config changes
```

### Production Hotfix

```bash
# 1. Check out production support ticket
./checkout-ticket.sh MOP-99999

# This automatically creates a hotfix branch from main
```

### Updating Translations

```bash
# Deploy i18n to dev for testing
./deploy-i18n.sh dev

# After testing, deploy to UAT
./deploy-i18n.sh uat

# Finally, deploy to production
./deploy-i18n.sh prod
```

### Generate Bi-weekly Report

```bash
# Run at the end of your sprint
./bi-weekly-report.sh

# Output is copied to clipboard - paste into your report
```

---

## Integration Points

### JIRA API

- **Endpoint**: `https://morrisonexpress.atlassian.net/rest/api/3/`
- **Authentication**: Basic auth using `JIRA_TOKEN`
- **Data Fetched**: Summary, parent ticket, issue type, priority, components

### GitHub CLI

- **Commands Used**: `gh pr list`, `gh pr create`
- **Authentication**: Uses GitHub CLI's configured credentials

### Jenkins

- **Base URL**: `https://jenkins.morrison.express/`
- **Authentication**: Basic auth using `JENKINS_TOKEN`
- **Jobs Triggered**: Various build and deployment jobs

---

## Raycast Integration

Several scripts include Raycast metadata for quick execution:

- `checkout-ticket.sh` - Quick ticket checkout
- `deploy-console.sh` - Deploy with dropdown options
- `deploy-i18n.sh` - Environment selection dropdown
- `deploy-one.sh` - Quick monorepo deployment

To use with Raycast, ensure scripts are executable and in your PATH.

---

## Project Paths

The scripts reference these project locations:

- **Monorepo**: `$HOME/project/mop-console-monorepo`
- **Console**: `$HOME/project/mop_console`

Make sure these directories exist and are properly set up.

---

## Troubleshooting

### "Command not found: gh"

Install GitHub CLI: `brew install gh`

### "Command not found: jq"

Install jq: `brew install jq`

### JIRA API returns 401

Check your `JIRA_TOKEN` format: `email@example.com:api-token`

### Jenkins deployment fails

Verify your `JENKINS_TOKEN` has correct permissions

### Branch already exists

Scripts will checkout existing branches instead of creating new ones

---

## Notes

- All scripts use `bash` shell with login mode (`#!/bin/bash -l`)
- PRs are created as drafts by default (`-d` flag)
- The scripts automatically handle branch creation and switching
- Deploy scripts require Jenkins server access

---

## Maintenance

When updating these scripts:

1. Test in a safe environment first
2. Update this README with any new functionality
3. Ensure backwards compatibility or update dependent scripts
4. Document any new environment variables required

---

## Known Issues

- `checkout-config.sh` has syntax errors in the conditional logic (line 26-28)
- `deploy-console.sh` has a typo in the conditional check (line 27)
