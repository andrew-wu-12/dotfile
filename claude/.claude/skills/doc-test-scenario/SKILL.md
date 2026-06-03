---
name: "doc-test-scenario"
description: "generate test scenarios for a feature spec or user story. Use this when asked to create test cases, write test scenarios, generate QA scenarios, or produce edge case coverage for a feature."
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

```plaintext
### Scenario: Submitting Empty Form
- **Precondition:** The user is logged in.
- **Action:** Click "Submit" button.
- **Expected Result:** Error message displays "Field cannot be empty".
```
