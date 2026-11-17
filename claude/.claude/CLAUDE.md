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

## Neovim + tmux
- Each worktree has its own tmux window: Neovim in one pane, Claude Code in another. Several Neovim instances run at once.
- To open a file in my Neovim, find the socket from tmux, not by probing every socket:
  1. `tmux display-message -p -t "$TMUX_PANE" '#{session_name}:#{window_index}'` gives this window.
  2. In that window, the Neovim pane's `pane_pid` has a child `nvim`, which has a child `nvim --embed`.
  3. The socket is `$TMPDIR/nvim.$USER/*/nvim.<embed pid>.0`.
- Open with `perl -e 'alarm 10; exec @ARGV' nvim --server <socket> --remote <absolute path>`. macOS has no `timeout`, and a call to another instance's socket can hang.
- `/ide` is only needed for `getDiagnostics`, which works only on files open in Neovim. Without it, run `tsc` / `eslint` instead.

## MOP monorepo
@~/.claude/mop-console-monorepo.md
