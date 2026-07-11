---
name: "doc-field-spec"
description: "produce a frontend field spec for a feature while reusing existing i18n keys. Use this when documenting a feature's fields and you want each field's i18n key resolved against existing keys (the feature's module + commons) before proposing new ones."
allowed-tools: Bash
---

# Field Spec with i18n Reuse Check

## Purpose

Generate a frontend field spec for a feature where every field's i18n key is
**resolved against keys that already exist** before any new key is proposed.
For each field's display text, `check-i18n.sh` searches the feature's own module
**and** `commons`, so shared wording is reused instead of duplicated.

## Inputs

- **module** — the module this feature belongs to, e.g. `billing`, `wms`, `tms`,
  `epod` (one of the modules in the i18n index). Passed by the caller.
  - If the module is not given, ask for it. If the caller declines, run
    commons-only (omit the second argument).
- **fields** — for each field: field name, display text, and field type if known.

## Workflow

For every field, resolve its i18n key from its display text:

1. Run the check (module-aware):

   ```bash
   ~/bin/check-i18n.sh "<display text>" <module>
   ```

   Searches `<module>` first, then `commons`. Module matches win ties.

2. Interpret the result and set the key + **Reuse** status:

   | Script output      | Action                                                              | Reuse     |
   | ------------------ | ------------------------------------------------------------------- | --------- |
   | `EXACT_KEY_MATCH`  | Reuse the returned key. Do **not** create a new key.                | `reused`  |
   | `EXACT_VALUE_MATCH`| Reuse the returned key. Do **not** create a new key.                | `reused`  |
   | `SIMILAR_MATCHES`  | Reuse the closest listed key; note the alternatives for review.     | `similar` |
   | `NO_MATCH`         | Propose a new key `<module>.<snake_case_of_text>`.                  | `new`     |

3. Never invent a module/key/value the script did not return. Only `new` rows
   introduce keys, and only in `{module}.{lowercase_with_underscores}` form.

## Output

Emit a field table. Columns extend the `doc-field-table-spec` format with a
**Reuse** column recording how the i18n key was resolved:

| **Field Name** | **Field Type** | **I18n Key**         | **I18n Value** | **Reuse** | **Detail** | **Warnings** |
| -------------- | -------------- | -------------------- | -------------- | --------- | ---------- | ------------ |
| `invoice_no`   | `text`         | `billing.invoice_no` | Invoice No     | reused    | ...        | None         |

- **Reuse**: `reused` (existing key), `similar` (candidate found — flag for
  manual review), or `new` (proposed key, did not exist before).
- For `similar` rows, list the candidate keys returned by the script in
  **Warnings** so a reviewer can confirm the choice.

## Rules

- **NO GUESSING** — use only field details provided and keys the script returns.
- **Field Type**: must be one of the accepted values in `doc-field-table-spec`.
- **I18n Key format**: `{module}.{lowercase_with_underscores}` (see `format-i18n-key`).
- **Default module**: fall back to `commons` only when no module can be determined.
