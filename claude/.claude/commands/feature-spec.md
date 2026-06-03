---
description: "Write a full feature specification in Traditional Chinese directly from a Jira ticket ID. Use when you already know the ticket is a feature ticket."
allowed-tools: Bash
---

# Feature Spec Writer

**Ticket ID:** $ARGUMENTS

## Workflow

1. Use the `tool-ticket-get` skill to fetch the ticket's title, description, issue type, and labels.
2. Generate the full specification below using only concrete details from the ticket.

---

## Spec Output

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
