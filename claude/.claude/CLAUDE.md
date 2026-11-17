# Global User Instructions

I work on MOP projects (React.js / TypeScript frontends, monorepo structure).

## Response Style
- Concise and direct. No trailing summary after completing a task.
- Use English by default; switch to Traditional Chinese only if I write in Chinese first.
- No comments in code at all.

## Code Review Output
- Number review findings with stable IDs (F1, F2, ...) and list them in that order. Never reorder or renumber them in later messages.
- When the user says "fix 3, 4, 5", restate which findings those are before editing.
- For each finding, give a verdict: valid, false positive or needs discussion, with evidence (file:line).

## MOP monorepo
@~/.claude/mop-console-monorepo.md
