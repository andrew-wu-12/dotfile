---
name: "doc-test-scenario"
description: "a basic rule for creating a test scenario for specs"
---

# Test Scenario Builder Skill

## Purpose:

Automatically generates high-quality test scenarios based on user actions and specs.

## Features:

1. Dynamically builds tests for main functionalities and edge cases based on the provided user actions.
2. Generates negative test cases (e.g., invalid inputs).
3. Formats scenarios into clear sections: Preconditions, Actions, Expected Results.

## Workflow:

1. Analyze user actions and view state to determine the steps for testing.
2. Include edge cases for potential failures (e.g., invalid API requests).
3. Produce scripted test outputs for manual/automated validation.

## Generated Test Scenario Example:

```plaintext e
### Scenario: Submitting Empty Form
- **Precondition:** The user is logged in.
- **Action:** Click "Submit" button.
- **Expected Result:** Error message displays "Field cannot be empty".
```
