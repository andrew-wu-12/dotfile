# mop-console-monorepo rules

Applies only when working in `mop-console-monorepo` or one of its worktrees. Ignore in other projects.

## Scope
- Do exactly what was asked. A rename is rename-only, with no behavior changes.
- Do not modify shared `libs/` components unless explicitly asked. Keep the fix in the app-level (CFS/TMS) component.
- Before writing new UI, search for an existing common component (copy button, overlay, field config) and reuse it.
- No code comments.

## Tests (Jest)
- Use `test()` / `test.each()`. If an existing file uses `it` throughout, ask.
- Description format: `with <condition> | expect: <result>`.
- Parameterized cases are row tables, each row holding every input and the expected value.
- Name the `describe` after the function under test.
- Check test data against the spec's validation rules before writing it.

## Code
- Never hard-code date format strings. Use the shared date-format constants and parse helpers.
- Use `import type` for type-only imports.

## Worktrees and branches
- Run reads and edits inside the current worktree, not the main checkout. Confirm with `git rev-parse --show-toplevel`.
- If a named branch or ticket doesn't exist, list close matches and ask before acting.

## Spec workflow
- Spec-challenge questions: one clear question, concrete options, a recommendation.
- Attribute decisions correctly in summaries ("you chose", not "I chose").
- Tag drift findings with confidence. Don't overstate severity.
