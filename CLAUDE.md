# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A personal dotfile and dev-environment setup repo for macOS. It uses **GNU Stow** to symlink config directories into their expected locations in `$HOME`. The repo has no build step, no test suite, and no package manager at the root level.

## Directory Layout and Stow Targets

Each top-level directory is a Stow package. Running `stow <pkg>` from the repo root creates symlinks under `$HOME` that mirror the package's internal structure:

| Directory | Stow target | What gets linked |
|-----------|-------------|-----------------|
| `zsh/` | `$HOME` | `.zshrc` |
| `bin/` | `$HOME/bin` | all `*.sh` scripts |
| `claude/` | `$HOME` | `.claude/settings.json`, `.claude/CLAUDE.md`, `.claude/skills/*` |
| `nvim-stow/` | `$HOME` | `.config/nvim/` |
| `starship/` | `$HOME` | `.config/starship.toml` |
| `tmux/` | `$HOME` | `.tmux.conf` |
| `wezterm/` | `$HOME` | `.wezterm.lua` |
| `opencode/` | `$HOME` | `.opencode/` |

All stowing goes through `stow_pkg` in `bin/init-lib.sh`, never `stow` directly. It dry-runs first, and if a real (non-symlink) file already occupies a target it lists the conflicts and asks whether to keep them. Keeping skips that package entirely; declining backs the files up to `<name>.bak.<timestamp>` and links the repo version. `--adopt` is deliberately **not** used anywhere — the repo is always the source of truth and is never written to by an init script.

`bin/init-lib.sh` also provides `resolve_repo_root` (scripts must not assume the repo is the parent of their own directory — that breaks when they run via the `~/bin` symlink) and `ensure_brew` (a freshly installed Homebrew is not on `PATH` until `brew shellenv` is evaluated).

## Initial Setup

```bash
cd ~/dotfile/bin
chmod +x *.sh
./init.sh          # interactive; walks through required + optional tools
source ~/.zshrc
```

`init.sh` orchestrates a sequence of `init-*.sh` sub-scripts. Optional tools (Starship, opencode, Nvim, Tmux, WezTerm, recommended CLI tools) are each prompted individually — pressing Enter skips.

On a fresh Mac the first step is `init-brew.sh`, which installs Homebrew (confirming first, since it needs `sudo` and pulls in Xcode Command Line Tools). Every other step depends on it.

Steps already satisfied are skipped, **except** those in `ALWAYS_RUN_KEYS` (currently `base`). Restowing is idempotent, and skipping it is how `~/bin` silently drifts from the repo when a new script is added — so it always runs.

Everything targets macOS on Apple Silicon; Homebrew is assumed at `/opt/homebrew`. All scripts must run under the stock `/bin/bash` 3.2 — no associative arrays, `mapfile`, or other Bash 4+ features.

## Credentials

Tokens are stored in macOS Keychain, never in plaintext. `.zshrc` reads them at shell start with `security find-generic-password`. To add or update a token:

```bash
security add-generic-password -a "$USER" -s "<service-name>" -w "<token>" -U
```

Service names: `jenkins.morrison.express`, `morrisonexpress.atlassian.net`, `getdata.morrison.express`.

## Key Scripts in `bin/`

All scripts are symlinked to `~/bin/` and have aliases in `.zshrc`:

- **`checkout-ticket.sh` (`crt <MOP-XXXX>`)** — Queries JIRA for ticket metadata, creates `uat/<parent>` and `feature/<ticket>` branches in `$MOP_MONOREPO_PATH`, opens draft PRs via `gh`. Requires VPN. This is the **legacy single-checkout** path: it `git add . && git stash`es the working tree and checks the new branch out **in place**, moving the main checkout's HEAD. Kept as a safety net; for parallel ticket work use `wt` instead.
- **`worktree-ticket.sh` (`wt <MOP-XXXX>`)** — Worktree-native alternative to `crt`. Same JIRA lookup, `uat/<parent>` + `feature/<ticket>` branches, and draft PRs, but creates the branches **without checkout** (via `git commit-tree`) and materializes `feature/<ticket>` as a git worktree under `$MOP_WORKTREE_ROOT`. Never moves the main checkout's HEAD and never stashes. APFS-clones `node_modules` and opens a tmux dev window. See [Parallel Ticket Workspaces](#parallel-ticket-workspaces-git-worktrees). No VPN needed (JIRA Cloud + GitHub are public).
- **`worktree-done.sh` (`wtd [--force]`)** — Tears down the worktree you are currently inside: closes its tmux window, `git worktree remove`, safe `git branch -d`, `git worktree prune`. Refuses the main checkout; refuses a dirty worktree without `--force`.
- **`ticket-lib.sh`** — Shared zsh JIRA/PR helpers (`get_ticket_content`, `pr_get_params/content/title`, …) sourced by both `crt` and `wt` so the two onboarding scripts never drift. Sourced via `${0:A:h}/ticket-lib.sh`, never executed.
- **`tmux-dev-layout.sh` (`dev`)** — Builds the VSCode-style tmux window (nvim + command + claude) for the current repo/worktree. Idempotent by window name; names windows `{branch}({repo})`.
- **`tmux-agent-notify.sh`** — Claude Code notification hook for worktree sessions; see [Parallel Ticket Workspaces](#parallel-ticket-workspaces-git-worktrees).
- **`tmux-window-picker.sh` (`prefix w`)** — Vertical "tab" switcher: an fzf popup listing every window across all sessions (`list-windows -a`), each row `session │ 🔴/🟢 name`, with a colored `capture-pane` preview. Enter switches (across sessions via `switch-client` + `select-window`); Esc cancels. Read-only navigator — it never creates/renames/kills windows, leaving lifecycle to `wt`/`wtd`. Replaces native `choose-tree`; styled to catppuccin mocha.
- **`checkout-config.sh` (`crc <MOP-XXXX>`)** — Opens the `[DEV]` `feature/MOP-XXXX → dev` draft PR for the `mop_configuration_files` repo; uat/master promotion PRs are made by hand.
- **`deploy-one.sh` (`dpo`)** — Triggers both `monorepo_feature` and `monorepo_uat` Jenkins jobs simultaneously.
- **`trace-build.sh` (`tbs`)** — Polls Jenkins for the current branch's build status; renders a live progress bar and sends a macOS notification on completion.
- **`bi-weekly-report.sh` (`bws`)** — Pulls PRs assigned to the current user from the monorepo via `gh`, formats them as JSON, and copies to clipboard.

## Environment Variables (`.zshrc`)

| Variable | Purpose |
|----------|---------|
| `MOP_CONSOLE_PATH` | Path to `mop_console` repo |
| `MOP_MONOREPO_PATH` | Path to `mop-console-monorepo` repo |
| `MOP_CONFIGURATION_PATH` | Path to `mop_configuration_files` repo |
| `MOP_EPOD_PATH` | Path to `mop_epod` repo |
| `NX_CACHE_DIRECTORY` | `~/.cache/nx-mop` — shared nx task cache across the main checkout and every worktree |
| `JENKINS_TOKEN` | Read from Keychain at shell start |
| `JIRA_TOKEN` | Read from Keychain at shell start |
| `GETDATATOKEN` | Read from Keychain at shell start |
| `SKILL_PATH` | `~/.opencode/skills` (for opencode agent skills) |
| `MCP_PATH` | `~/dotfile-mcp-server` (local MCP server for opencode) |

## Tmux Shortcuts

`prefix` is `Ctrl-B`. Notable bindings:
- `prefix Ctrl-O` — opens opencode in a popup (90% of terminal)
- `prefix Ctrl-G` — opens lazygit in a popup
- `prefix w` — vertical window "tab" picker (fzf popup, all sessions, colored preview); `tmux-window-picker.sh`, replaces native choose-tree
- `prefix Ctrl-S` / `prefix Ctrl-R` — tmux-resurrect save / restore
- Navigation via vim-tmux-navigator: `Ctrl-h/j/k/l` and arrow variants

Session persistence comes from `tmux-resurrect` + `tmux-continuum`: saves every 5 minutes and restores on tmux server start, so sessions survive a reboot. `tmux-continuum` must stay the **last** `@plugin` entry, and it prepends its save hook to `status-right` — any `set -g status-right` must therefore run *before* `run '~/.config/tmux/plugins/tpm/tpm'`, or the hook is wiped and auto-save silently stops.

The status bar renders the window **name** (`#W`), not the pane title: `@catppuccin_window_text` / `@catppuccin_window_current_text` are overridden to `" #W"` before `catppuccin.tmux` runs. catppuccin defaults both to `#T`, which Claude Code and nvim continuously overwrite with their own pane titles — so `tmux-dev-layout.sh`'s `{branch}({repo})` names and `tmux-agent-notify.sh`'s 🔴/🟢 markers were being set correctly but never appearing on screen.

## Parallel Ticket Workspaces (git worktrees)

`wt` / `wtd` give one workspace per ticket so you can context-switch between tickets **without `git stash`**. Each ticket is a git worktree under `$MOP_WORKTREE_ROOT` (default `~/project/worktrees/MOP-XXXX`), deliberately **outside** the repo so it never appears in the main checkout's `git status`. Worktrees must stay on the same **APFS** volume as the repo (the `node_modules` clone below depends on it).

Invariants the scripts guarantee:

- **The main checkout is never disturbed.** `wt` creates branches with `git branch` / `git commit-tree` (no checkout), so the main checkout's HEAD stays put and nothing is ever stashed. Branches must be created *before* `git worktree add`, which refuses a branch already checked out elsewhere. (`crt` is the opposite — it stashes and checks out in place.)
- **`node_modules` is APFS copy-on-write cloned**: a worktree costs ~0 disk, and a `yarn install` in one ticket cannot mutate another's deps. This is why it is cloned, not symlinked. The clone goes through `clonefile(2)` on the directory (one kernel call for the whole hierarchy, ~5s), *not* `cp -c -R` — `cp` clones the same blocks but walks 214k entries one `copyfile(2)` at a time, which took ~4 min. Bash cannot issue a raw syscall, so it is invoked via a short `/usr/bin/python3 -c` `ctypes` shim, with `cp -c -R` kept as a fallback. `clonefile` requires the destination not to exist.
- **The nx cache is shared**, not duplicated. `NX_CACHE_DIRECTORY` is an absolute path, so every workspace resolves to `~/.cache/nx-mop` (verified against `node_modules/nx/src/utils/cache-directory.js`, which reads the env var and precedes `nx.json`). Prune it with `rm -rf ~/.cache/nx-mop` or `nx reset`; never let it grow per-worktree.
- **`yarn serve` does not parallelize.** This is a Module Federation monorepo with hardcoded per-app ports (`apps/*/project.json`), so only one worktree can serve at a time — serve serially, in whichever worktree you are reviewing. Tests, builds, lint, and typecheck are worktree-isolated and safe to run concurrently.

**Window naming.** `tmux-dev-layout.sh` names every tmux window `{branch}({repo})` (e.g. `feature/MOP-27970(mop-console-monorepo)`); the repo half comes from the git *common dir*, so it is the real project name even inside a worktree. Window reuse and `wtd` match this name as a **suffix**, so a notification marker prefix (below) never spawns a duplicate window.

**Notifications.** `tmux-agent-notify.sh` is registered globally as Claude Code `Notification` / `Stop` / `UserPromptSubmit` hooks in `claude/.claude/settings.json`, but **self-guards** to act only when the agent's cwd is under `$MOP_WORKTREE_ROOT`. It renames the agent's window `🔴 …` (needs input) / `🟢 …` (turn done) and clears the marker on the next prompt, plus fires a macOS notification — **suppressed when you are already looking at that window**, so you are only pinged about tickets elsewhere. "Looking at it" requires all three of window active, session attached, *and* the terminal app frontmost: tmux cannot see that you alt-tabbed to a browser (the window stays active), so the frontmost check — `lsappinfo`, walking the tmux client's process tree up to the terminal GUI — is what keeps the popup from being suppressed exactly when you are away from the machine. The hook **must stay silent on stdout**: Claude Code injects a `Stop`/`UserPromptSubmit` hook's stdout back into the conversation as context. Hook changes take effect only in the *next* `claude` launched.

## opencode Config

`opencode/.opencode/opencode.json` sets the model to `github-copilot/gpt-4o` and loads a local MCP server (`dotfile-mcp-server`) and the `opencode-agent-skills` plugin.

## Modifying This Repo

- Edit config files in their package directories (e.g., `zsh/.zshrc`, `nvim-stow/.config/nvim/`), not their symlinked locations in `$HOME`.
- After adding a new file to a package, re-run `stow --restow <pkg>` from the repo root to update the symlink.
- Scripts added to `bin/` are automatically available as `~/bin/<script>` after stow; add aliases to `zsh/.zshrc` as needed.
