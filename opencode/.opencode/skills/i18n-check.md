---
name: check-i18n
description: Check if UI text or i18n keys exist in the project translation files.
---

To check if a specific text or key exists in the i18n configuration:

1.  **Run the helper script:**
    Use the `bash` tool to execute:
    ```bash
    ~/bin/check-i18n.sh "<text_or_key>"
    ```

2.  **Interpret the Output:**
    *   **EXACT_KEY_MATCH:** The key exists. Use the returned key.
    *   **EXACT_VALUE_MATCH:** The text exists as a value. Use the returned key.
    *   **SIMILAR_MATCHES:** The text is similar to existing values.
        *   If the meaning is identical, consider reusing the existing key.
        *   If the meaning differs, propose a new key but note the similarity.
    *   **NO_MATCH:** The text/key does not exist.
        *   Propose a new key following the format: `[module_name].[snake_case_text]`.
        *   Mark it as `[NEW]`.

3.  **Handling New Keys:**
    *   New keys should be namespaced by module (e.g., `auth.login_failed`).
    *   Use snake_case for the key suffix.
