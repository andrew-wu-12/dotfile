---
description: "Fetch a Jira ticket, classify it as feature or non-feature, and generate a full Traditional Chinese spec for feature tickets."
allowed-tools: Bash
---

# Ticket Spec Generator

**Ticket ID:** $ARGUMENTS

## Workflow

### Step 1 — Fetch
Use the `tool-ticket-get` skill to retrieve the ticket's title, description, issue type, and labels.

### Step 2 — Classify
Classify the ticket as one of:

- **feature**: new user-facing capability (view, form, workflow), API work for the above, new fields/columns/filters/actions
- **non-feature**: bug fix, regression fix, refactor/clean-up, spike, infrastructure-only
- **ambiguous**: conflicting or missing details

Log the classification decision and rationale before proceeding.

### Step 3 — Act

**If non-feature**, stop and respond:
> 此 ticket 不屬於功能性需求。請告知下一步，例如產出 bug spec 或忽略。

**If ambiguous**, ask the user for clarification.

**If feature**, generate the full spec below.

---

## Feature Spec Output

Output **entirely in Traditional Chinese** unless technically required (API names, code snippets, table syntax).

Use the following skills as needed during generation:
- `doc-field-table-spec` — for frontend field tables
- `doc-api-spec` — for API request/response payloads
- `doc-test-scenario` — for test scenarios and edge cases

### 1. 前端規格
- **頁面/視圖：** [名稱]
  - 欄位規格：（使用 `doc-field-table-spec`）
- **使用者操作：**
  - [操作名稱]
- **視圖邏輯：**
  - 載入、錯誤及邊界狀態處理

### 2. 後端規格
- API 端點（使用 `doc-api-spec`）

### 3. 測試案例情境
- 邊界案例（使用 `doc-test-scenario`）

**STRICT RULES:**
- NO GUESSING — use only concrete details from the ticket.
- Never infer fields, APIs, or behaviors not stated in the ticket.
