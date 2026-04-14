---
name: "doc-field-table-spec"
description: "a basic rule for creating a frontend field table for jira"
---

# Jira Table Validation Rules

## Purpose

This skill encompasses the validation rules, structure, and processing requirements for Jira tables. It ensures proper field validation, internationalization (i18n) key formatting, and implementation of detailed logging mechanisms.

---

## Field Column Example

Below is an example detailing the expected format and values for field columns:

| **Field Name**  | **Field Type**     | **I18n Key**         | **I18n Value** | **Detail** | **Warnings** |
| --------------- | ------------------ | -------------------- | -------------- | ---------- | ------------ |
| `field_example` | async-multi-select | module.field_example | Example Value  | Metadata   | None         |

---

## Rules to Follow

### Field Column Rules:

1. **Field Name**:

   - Must use `lowercase_with_underscores`.

2. **Field Type**:

   - Should be one of the following accepted values:
     - `tagInput`, `select`, `multi-select`, `async-multi-select`, `async-select`,
     - `async-auto-suggestion`, `date-text-input`, `date-range-text-input`,
     - `date-range-with-type`, `number-range-input`, `number-text`,
     - `textarea`, `checkbox-uni`, `checkbox-multi`, `react-datasheet-bulk-update`,
     - `switch-button`, `radio-buttons`, `text`, `quill-editor-and-previewer`,
     - `virtual-keyboard`, `upload-document-card`, `phone`.

3. **I18n Key**:

   - Must include `module` and `key` components.
   - Rules for `module`:
     - Must be one of the following:
       - `billing`, `cfs`, `commons`, `config`, `ct`, `customer_report`,
         `devops`, `edi`, `epod`, `hrs`, `kpi`, `maintain`, `packing_station`,
         `pricebook`, `shalog`, `shpt`, `sop_mgmt`, `sys`, `task_mgmt`,
         `tms`, `user_registration_mgmt`, `utilities_mgmt`, `wms`.
   - Rules for `key`:
     - Must be a string with lowercase characters and underscores.

4. **I18n Value**:

   - The original text to be used.

5. **Detail**:

   - Provide a detailed description of the field, e.g., options for a select field.

6. **Warnings**:
   - Clearly list warnings, especially when specifications are incomplete or unusual.

---

## Enhanced Practices

- **Validation Enforcement**:

  - Ensure `Field Type` accepts only predefined keys. Log validation results (e.g., passed, skipped, bypassed).
  - Add logs for unrecognized/deviating field types.

- **Default Module**:

  - Default `module_name` to `commons` when a specific module is unidentifiable.

- **I18n Key Validation Logging**:
  - Enforce `{module_name}.{lowercase_with_underscores}` for i18n key validation.
  - Log any failures or skipped validations for query/result columns.

---

This structured skill ensures consistent validation and processing for Jira tables.
