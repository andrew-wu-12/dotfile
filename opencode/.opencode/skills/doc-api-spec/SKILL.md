---
name: "doc-api-spec"
description: "a basic rule for creating a api payload"
---

# API Payload/Template Generator

## Purpose:

Automates the creation and validation of API request/response payload structures.

## Features:

1. Generates `Request Payload` JSON structures for endpoints.
2. Creates `Response Payload` templates with placeholders for missing details.
3. Flags unclear fields for manual review or populates them as `[MISSING]`.

## Workflow:

1. Parse API endpoint details (method, purpose, fields).
2. Auto-generate payload structure based on conventions.
3. Verify correctness and compliance with backend standards.
4. Return structured JSON to the agent.

## Code Example:

```json
{
  "request": {
    "id": "[MISSING]",
    "data": {
      "field1": "value1",
      "field2": "[MISSING]"
    }
  },
  "response": {
    "status": "success",
    "data": "[MISSING]"
  }
}
```
