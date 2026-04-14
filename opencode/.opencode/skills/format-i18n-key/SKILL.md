---
name: "format-i18n-key"
description: "a basic rule for creating a i18n key"
---

# i18n Key Management Skill

## Purpose:

Automates the process of managing internationalization (i18n) keys, including:

- Checking existing keys.
- Suggesting reusable keys.
- Proposing new keys in the required format: `[module_name].[snake_case_text]`.

## Features:

1. Executes the `check-i18n.sh` script to verify if the text elements exist in the system.
2. Suggests reusing a key if a "similar" match is found.
3. Proposes new keys in a compliant format if no match is found.
4. Records ambiguous cases for agent/manual review.

## Workflow:

1. Parse user-provided frontend text requiring i18n keys.
2. Execute `check-i18n.sh` to search for keys:
   - **Exact Match:** Return key.
   - **Similar Match:** Suggest potential reusability.
   - **No Match:** If uncertain, confirm the appropriate prefix with the user before proposing a new key:
     - Allowed prefixes: ["billing", "cfs", "commons", "config", "ct", "customer_report", "edi", "epod", "hrs", "kpi", "packing_station", "pricebook", "shalog", "shpt", "sop_mgmt", "sys", "task_mgmt", "tms", "user_registration_mgmt", "utilities_mgmt"].
3. Return matching results with clarity for agent usage.

## Code Example:

```bash
# Run the script
~/bin/check-i18n.sh "<Frontend Text>"
```
