---
name: pr-review-markdown-summary
description: >-
  Fetch a PR's inline review comments and print them as a markdown table,
  grouped by author, with each comment's fix status in the code and on
  GitHub. Use after you push fixes for review comments, or
  "pr-review-markdown-summary", or "summarize the PR comments". Read-only —
  it never replies to a thread and never resolves a thread.
---

# PR Review Markdown Summary

This skill reports the state of a PR's review comments. It groups the
comments by author. It checks each comment against the current diff. It
prints one markdown table per author.

## Prerequisites

- `gh` is authenticated.
- The worktree is on the PR's branch.
- The PR is open.

## Workflow

### 1. Find the PR

Run this command:

```bash
gh pr view --json number,headRefName,url
```

If the user gives a PR number or a ticket ID, use it instead of the
current branch.

If no open PR exists, stop. Tell the user. Do not create a PR.

### 2. Fetch the review threads

Get the repo owner and name:

```bash
gh repo view --json owner,name --jq '{owner: .owner.login, name: .name}'
```

Run this query. Use the owner, the name, and the PR number from step 1:

```bash
gh api graphql -f query='
query {
  repository(owner: "<OWNER>", name: "<NAME>") {
    pullRequest(number: <NUMBER>) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          comments(first: 50) {
            nodes {
              path
              line
              body
              author { login __typename }
            }
          }
        }
      }
    }
  }
}'
```

Each thread has a resolved flag and a list of comments. Each comment has
an author, a file path, a line number, and a body.

### 3. Remove bot comments

Check each comment's author type.

Remove a comment when the author type is `Bot`.

Keep only comments from human reviewers.

### 4. Group the comments by author

Group the comments by the comment's own author. Do not group a reply
under the parent comment's author.

Give a reply a short note. State whose comment it replies to.

If no comments remain after step 3, stop. Tell the user the PR has no
open review comments from a human reviewer.

### 5. Check the code against each comment

Get the PR diff:

```bash
git diff origin/main...HEAD
```

Read the diff. Compare it against each comment. Decide a code status for
each comment: `Fixed`, `Open`, or `N/A`.

Pick a method with this rule:

1. The PR touches 3 files or fewer, and has 5 comments or fewer: read the
   diff yourself.
2. The PR touches more than 3 files, or has more than 5 comments: send
   the diff and the comments to a subagent. Ask the subagent to return a
   code status and one action sentence for each comment. Do not accept a
   raw diff dump back — only the per-comment verdicts.

### 6. Mark the interpreted rows

A question-style comment has no direct instruction. Its code status needs
judgment, not a direct match.

Add a short note to this kind of row. State that the status is an
interpretation.

Do not add this note to a comment with a direct instruction and a
matching code change.

### 7. Build the tables

Build one table for each author. Give each table these columns:

| Column | Content |
|---|---|
| File:Line | the comment's path and line number |
| Comment | the comment's exact text, unedited and untranslated |
| Action Taken | one sentence on what the code now does about the comment |
| Code | `Fixed`, `Open`, or `N/A` |
| GitHub Thread | `Resolved` or `Open`, from the thread's resolved flag |

Add one exception note under a row only when its thread is resolved but
the code shows no matching change.

Do not add a note when the code is fixed but the thread stays open. This
is the normal case right after a push.

### 8. Pick the report language

Check the language of the user's request.

Write the table headers and the Action Taken column in that language.
Default to English. Switch to Traditional Chinese only when the user's
own request uses Chinese.

Never translate the Comment column. Keep each comment in its original
language.

### 9. Write the closing line

State the commit SHA and the branch the report reflects.

State the code tally: the fixed count out of the total comment count.

State the GitHub thread tally: the resolved count out of the total
thread count.

## Output Format

```markdown
### <author>

| File:Line | Comment | Action Taken | Code | GitHub Thread |
|---|---|---|---|---|
| `path/to/file.ts:42` | original comment text | what changed | Fixed | Open |
```

Repeat the table per author. End with the closing line from step 9.

## Rules

- This skill never replies to a GitHub thread.
- This skill never resolves a GitHub thread.
- This skill never writes a file. It prints the report in the chat.
- This skill never saves state between runs. Each run is a fresh check.
- Each run checks every thread, resolved and open. It does not skip a
  resolved thread.
