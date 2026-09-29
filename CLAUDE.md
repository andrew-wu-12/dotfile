# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A personal dotfile and dev-environment setup repo, targeting **macOS** (primary) and **Arch Linux**. It uses **GNU Stow** to symlink config directories into their expected locations in `$HOME`. The repo has no build step, no test suite, and no package manager at the root level.

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
| `vscode-stow/` | `$HOME` | `Library/Application Support/Code/User/settings.json` |
| `raycast/` | not stowed | `snippets.json`, imported manually via Raycast's own UI |

Several `bin/*.sh` scripts (`worktree-ticket.sh`, `deploy-one.sh`, `combine-branches.sh`, `deploy-i18n.sh`, `trace-build.sh`) carry `# @raycast.*` header comments, so the same script is both a `~/bin` CLI command and a Raycast Script Command (Raycast points its script-directory setting at `~/bin` and reads these headers to build its UI) — don't remove those comments as dead code.

All stowing goes through `stow_pkg` in `bin/init-lib.sh`, never `stow` directly. It dry-runs first, and if a real (non-symlink) file already occupies a target it lists the conflicts and asks whether to keep them. Keeping skips that package entirely; declining backs the files up to `<name>.bak.<timestamp>` and links the repo version. `--adopt` is deliberately **not** used anywhere — the repo is always the source of truth and is never written to by an init script.

`bin/init-lib.sh` also provides `resolve_repo_root` (scripts must not assume the repo is the parent of their own directory — that breaks when they run via the `~/bin` symlink), `ensure_brew` (a freshly installed Homebrew is not on `PATH` until `brew shellenv` is evaluated), and the package-manager abstraction described in [Platform Support](#platform-support).

## Initial Setup

```bash
cd ~/dotfile/bin
chmod +x *.sh
./init.sh          # interactive; walks through required + optional tools
source ~/.zshrc
```

`init.sh` orchestrates a sequence of `init-*.sh` sub-scripts. Optional tools (Starship, Nvim, Tmux, WezTerm, recommended CLI tools) are each prompted individually — pressing Enter skips.

On a fresh Mac the first step is `init-brew.sh`, which installs Homebrew (confirming first, since it needs `sudo` and pulls in Xcode Command Line Tools). Every other step depends on it. On Arch, pacman ships with the base system, so there is no equivalent bootstrap step — `init-brew.sh` is macOS-only and `detect_status brew` just confirms pacman is present.

Steps already satisfied are skipped, **except** those in `ALWAYS_RUN_KEYS` (currently `base`). Restowing is idempotent, and skipping it is how `~/bin` silently drifts from the repo when a new script is added — so it always runs.

All scripts must run under macOS's stock `/bin/bash` 3.2 — no associative arrays, `mapfile`, or other Bash 4+ features. This constraint is a macOS floor, not a ceiling: it also runs unmodified under Arch's modern Bash, so no separate Arch compatibility work is needed on that front.

## Platform Support

macOS is via Homebrew; Arch Linux is via pacman for official-repo packages and an AUR helper (`yay`) for everything else. `bin/init-lib.sh` provides the abstraction every `init-*.sh` script installs through:

- `detect_pkg_manager` — caches `"brew"` or `"pacman"` based on `uname -s` / `command -v pacman`.
- `ensure_pkg_manager` — macOS delegates to `ensure_brew`; Arch just confirms `pacman` exists.
- `ensure_aur_helper` — bootstraps `yay` on Arch (confirms first, since it builds from source via `makepkg`); no-op on macOS.
- `pkg_install <brew_name> [pacman_name] [cask|aur]` — installs a package by name. `pacman_name` defaults to `brew_name` (most packages here share a name across both, e.g. `starship`, `ripgrep`), pass it explicitly when they diverge (e.g. `pkg_install nvim neovim`). The `cask` modifier means `brew install --cask` on macOS and is a no-op on Arch (GUI apps are just regular packages there); `aur` means "not in Arch's official repos, install via `yay`" and is a no-op on macOS.
- `zsh_plugin_file <plugin>` — resolves the share-dir path for a zsh plugin (`/opt/homebrew/share/...` vs `/usr/share/...`); `.zshrc` guards its own `source` lines for both paths directly rather than calling into `init-lib.sh`, since it isn't sourced from a setup script.

Known package-name divergences, encoded at each call site rather than in a shared table (there are only two): `nvim`→`neovim` (`init-nvim.sh`), `wezterm` cask vs. the `extra`-repo package of the same name (`init-wezterm.sh`).

**Not yet ported to Arch** — these remain macOS-only and are out of scope for the package-manager abstraction: `osascript` desktop notifications, and `tmux-agent-notify.sh`'s frontmost-app detection (`lsappinfo`/LaunchServices bundle IDs — see [Notifications](#parallel-ticket-workspaces-git-worktrees)). Each needs its own Linux-side redesign (`notify-send`, and an X11/Wayland-specific focus-detection story, respectively) rather than a mechanical swap.

## Credentials

Tokens are stored encrypted, never in plaintext: macOS uses Keychain (`security`), Arch uses `secret-tool` (libsecret) against a Secret Service provider (gnome-keyring or equivalent) — this assumes a desktop login (GNOME/KDE) that unlocks the keyring via PAM; a minimal-WM setup with no such hook needs its own bootstrap, out of scope here. Both backends key items by `(service, account)`, so `init-lib.sh`'s `cred_find`/`cred_store` wrap the platform difference and `ensure_secret_backend` lazily installs `libsecret` on Arch if `secret-tool` is missing — it's called only from `init-credentials.sh`, never from `cred_find`/`cred_store`/`detect_status`, so status checks stay read-only rather than triggering a pacman install as a side effect. `.zshrc` reads tokens at shell start with its own local `_read_cred` helper (mirroring the same branch, since `.zshrc` doesn't source `init-lib.sh`) into **non-exported** shell variables, so no child process (Claude Code, MCP servers, npm lifecycle scripts, nvim plugins) inherits them. zsh scripts that `source ~/.zshrc` still see them; every other consumer falls back to `~/bin/cred-read.sh <service>` on demand (`: "${JIRA_TOKEN:=$(~/bin/cred-read.sh …)}"`), and a child that needs one gets it only as a command-prefix assignment (`GETDATATOKEN=… yarn download-options`, the codex MCP command's `OPENAI_API_KEY`). Never re-add `export` to those lines. To add or update a token, run `init-credentials.sh`, or store one directly:

```bash
# macOS
security add-generic-password -a "$USER" -s "<service-name>" -w "<token>" -U
# Arch
printf '%s' "<token>" | secret-tool store --label="<service-name>" service "<service-name>" account "$USER"
```

Service names: `jenkins.morrison.express`, `morrisonexpress.atlassian.net`, `getdata.morrison.express`, `openai.com`.

## Clipboard

macOS ships `pbcopy`/`pbpaste`, builtin. Arch has no equivalent, and which tool works depends on the session type: `wl-clipboard` (`wl-copy`/`wl-paste`) under Wayland, `xclip` under X11 — `init-lib.sh`'s `clip_copy`/`clip_paste` pick between them via `$WAYLAND_DISPLAY` at call time (only set under Wayland) rather than assuming one session type, and fall straight through to `pbcopy`/`pbpaste` when present. `ensure_clipboard_backend` lazily installs whichever tool is needed on Arch; unlike the credentials port, it's called directly from `clip_copy`/`clip_paste` since nothing polls them repeatedly the way `detect_status` polls credentials. `bin/init-ssh.sh`, `bin/setup-git-identity.sh`, and `bin/bi-weekly-report.sh` all source `init-lib.sh` and call `clip_copy` instead of `pbcopy` directly; `.zshrc`'s `gbc` alias uses its own local `_clip_copy` helper (same branch, since `.zshrc` doesn't source `init-lib.sh`).

## Key Scripts in `bin/`

All scripts are symlinked to `~/bin/` and have aliases in `.zshrc`. Read a script before changing it; this list only covers purpose and non-obvious constraints.

**Ticket / branch onboarding**
- **`worktree-ticket.sh` (`mwt [-n] <MOP-XXXX>`)** — Ticket onboarding for the MOP monorepo: JIRA lookup, `uat/<parent>` + `feature/<ticket>` branches, draft PRs. Creates branches without checkout (`git commit-tree`) and materializes `feature/<ticket>` as a worktree. No VPN needed. See [Parallel Ticket Workspaces](#parallel-ticket-workspaces-git-worktrees).
- **`worktree-generic.sh` (`wt [-n] <branch>`)** — Same for any repo: plain branch off the auto-detected default branch, local only (no push/PR).
- **`worktree-done.sh` (`wtd [--force]`)** — Tears down the current worktree (tmux window, worktree, safe `branch -d`, prune). Refuses the main checkout (via the `.git` file-vs-directory check) and dirty worktrees without `--force`.
- **`checkout-config.sh` (`crc <MOP-XXXX>`)** — Opens the `[DEV]` draft PR for `mop_configuration_files`; uat/master promotion PRs are manual.
- **`ticket-lib.sh`** — Shared zsh JIRA/PR helpers for `mwt` (also used by `tmux-ticket-status.sh` / `tmux-build-config.sh`). zsh-only, so bash callers shell out via `zsh -c`.
- **`worktree-lib.sh`** — Shared worktree helpers (node_modules clone, hook install, default branch, `.claude/settings.local.json` symlink) for `mwt`/`wt`. The monorepo's `autoMode` block (`environment` + `soft_deny`) lives in its gitignored `settings.local.json`, not in `claude/.claude/settings.json`, because this repo is public.

**Tmux workspace**
- **`tmux-dev-layout.sh` (`dev [-n]`)** — Builds the nvim + command + claude window, named `{branch}({repo})`. Idempotent: an existing matching window is selected, never duplicated. Session comes from `SESSION_GROUP` in `.workspace.conf` (via `workspace_config_load`, so the same walk and trust rules as below), falling back to the repo name.
- **`tmux-window-picker.sh` (`prefix w`)** — fzf popup: window switcher, MOP `yarn serve` control, JIRA ticket picker (`Tab` toggles), trace/deploy/browser/notes actions. Never creates/renames/kills windows itself — `mwt`/`wt`/`wtd` own that lifecycle.
- **`tmux-forgejo-picker.sh` (`prefix i`)** — Issue picker for the `homelab` repo (Forgejo); `enter` runs `wt -n` on `feature/<number>-<slug>`. Entirely separate from `prefix w`.
- **`tmux-ticket-status.sh`** — Print-and-exit ticket dev-status checklist used as `prefix w`'s preview pane. Three states: done / pending (normal not-yet-there) / error (the check itself failed). Hotfix tickets have no `uat/<parent>`, so epic rows render N/A. Uncached.
- **`tmux-serve-lib.sh`** — Single-`yarn serve` bookkeeping shared by the picker (bash) and `wtd` (zsh); only one MOP serve can run since ports are hardcoded.
- **`tmux-agent-notify.sh`** — Claude Code notification hook; see [Parallel Ticket Workspaces](#parallel-ticket-workspaces-git-worktrees).

**Build / deploy**
- **`tmux-build-config.sh`** — Resolves a worktree's `.tmux-build.conf` / `.workspace.conf` by sourcing every one from `$HOME` down to the directory *containing* the git toplevel, outer to inner (closer file overrides by reassignment). Files inside the repo are never sourced (repo content, a PR branch, or an agent's write would otherwise run on every `prefix w`), nor are files not owned by `$USER` or group/world-writable — per-repo config goes in `$WORKTREE_ROOT/<repo>/`. Resolves `BUILD_JOBS` roles (`current`/`base`/`jira_parent`); every role falls back to the worktree's own branch on failure rather than erroring.
- **`tmux-build-trace-lib.sh`** — Backend-agnostic trace engine used by the picker's `ctrl-g` (popup) and `ctrl-p` (inline post-deploy trace). Popups are opened via delayed `tmux run-shell -b` because tmux shows one popup at a time and the picker is already in one. Build discovery retries ~16s since a just-triggered build sits in the CI queue first.
- **`tmux-build-trace.sh`** — The `ctrl-g` trace popup; not run directly. Waits for a keypress when done, then reopens the picker.
- **`tmux-build-backend-<name>.sh`** — Backends dispatched by `BUILD_BACKEND` (`jenkins`, `forgejo`), each defining `<name>_find_build`/`<name>_poll_build` with the same JSON shape. Forgejo traces one combined commit status per ref (the job field is unused) and branch names with `/` must be percent-encoded or its router 404s.
- **`tmux-deploy-lib.sh`** — `deploy_trigger_job`, sourced by both `deploy-one.sh` (zsh) and the picker (bash), so it must stay in syntax both shells understand (no arrays / indirect expansion).
- **`deploy-one.sh` (`dpo`)** — Triggers `mop_console_monorepo_dev` and `_uat` Jenkins jobs for the same branch.
- **`trace-build.sh` (`tbs`)** — Polls Jenkins for the current branch's build with a progress bar and macOS notification.
- **`bi-weekly-report.sh` (`bws`)** — Copies the user's monorepo PRs as JSON to the clipboard.

MOP's 4-job trace config lives in `$WORKTREE_ROOT/mop-console-monorepo/.tmux-build.conf` — in the worktree-namespace folder, not the repo, so it covers every worktree regardless of branch.

## Environment Variables (`.zshrc`)

| Variable | Purpose |
|----------|---------|
| `MOP_CONSOLE_PATH` | Path to `mop_console` repo |
| `MOP_MONOREPO_PATH` | Path to `mop-console-monorepo` repo |
| `MOP_CONFIGURATION_PATH` | Path to `mop_configuration_files` repo |
| `MOP_EPOD_PATH` | Path to `mop_epod` repo |
| `WORKTREE_ROOT` | `~/project/worktrees` — root for all `mwt`/`wt` worktrees, namespaced per-repo underneath |
| `NX_CACHE_DIRECTORY` | `~/.cache/nx-mop` — shared nx task cache across the main checkout and every worktree |
| `JENKINS_TOKEN` | Read from Keychain at shell start (not exported) |
| `JIRA_TOKEN` | Read from Keychain at shell start (not exported) |
| `GETDATATOKEN` | Read from Keychain at shell start (not exported) |

## Tmux Shortcuts

`prefix` is `Ctrl-B`. Notable bindings:
- `prefix Ctrl-G` — opens lazygit in a popup
- `prefix Ctrl-E` — opens nvim in a popup, same path as the current pane
- `prefix w` — vertical window "tab" picker and MOP `yarn serve` control (fzf popup, all sessions); `tmux-window-picker.sh`, replaces native choose-tree. Highlighting a MOP worktree card shows its ticket dev-status report (`tmux-ticket-status.sh`) in a preview pane. `Tab` toggles in a second row set: JIRA tickets assigned to you with no worktree yet (absorbs the old `prefix j` picker).
- `prefix i` — Forgejo issue picker for the `homelab` repo, `tmux-forgejo-picker.sh`; separate from `prefix w`'s JIRA-driven picker.
- `prefix Ctrl-S` / `prefix Ctrl-R` — tmux-resurrect save / restore
- Navigation via vim-tmux-navigator: `Ctrl-h/j/k/l` and arrow variants

Session persistence comes from `tmux-resurrect` + `tmux-continuum`: saves every 5 minutes and restores on tmux server start, so sessions survive a reboot. `tmux-continuum` must stay the **last** `@plugin` entry, and it prepends its save hook to `status-right` — any `set -g status-right` must therefore run *before* `run '~/.config/tmux/plugins/tpm/tpm'`, or the hook is wiped and auto-save silently stops.

The status bar renders the window **name** (`#W`), not the pane title: `@catppuccin_window_text` / `@catppuccin_window_current_text` are overridden to `" #W"` before `catppuccin.tmux` runs. catppuccin defaults both to `#T`, which Claude Code and nvim continuously overwrite with their own pane titles — so `tmux-dev-layout.sh`'s `{branch}({repo})` names and `tmux-agent-notify.sh`'s 🔴/🟢 markers were being set correctly but never appearing on screen. **The horizontal window list is now hidden** (`window-status-format ""`) for a minimal top bar — window switching is the vertical `prefix w` picker instead. This blanking **must be the last thing in `.tmux.conf`**: catppuccin sets these formats, and so does `run '.../tpm/tpm'` when TPM re-sources `catppuccin.tmux`, so any earlier placement is overwritten (both loads are async `run-shell`, so file order before TPM doesn't help). The `@catppuccin_window_text " #W"` overrides are consequently inert but kept so unhiding the list works without rewiring; the 🔴/🟢 markers live in the window *name*, so they still show in the picker and still fire macOS notifications regardless of the bar.

## Parallel Ticket Workspaces (git worktrees)

`mwt` (MOP, JIRA ticket-driven) and `wt` (generic, any repo, plain branch name) both give one workspace per ticket/branch so you can context-switch **without `git stash`**, and both are torn down the same way by `wtd`. Each workspace is a git worktree under `$WORKTREE_ROOT/<repo-name>/<ticket-or-branch>` (default root `~/project/worktrees`), deliberately **outside** the repo so it never appears in the main checkout's `git status`. Worktrees must stay on the same **APFS** volume as the repo (the `node_modules` clone below depends on it).

Invariants the scripts guarantee:

- **The main checkout is never disturbed.** `mwt` creates branches with `git branch` / `git commit-tree` (no checkout); `wt` creates them with plain `git branch` off the repo's auto-detected default branch. Either way the main checkout's HEAD stays put and nothing is ever stashed. Branches must be created *before* `git worktree add`, which refuses a branch already checked out elsewhere.
- **`node_modules` is APFS copy-on-write cloned**, via the shared `wt_clone_node_modules` helper in `worktree-lib.sh` (used by both `mwt` and `wt`, no-op if the repo has no `node_modules`): a worktree costs ~0 disk, and a `yarn`/`npm install` in one workspace cannot mutate another's deps. This is why it is cloned, not symlinked. The clone goes through `clonefile(2)` on the directory (one kernel call for the whole hierarchy, ~5s for MOP's 214k files), *not* `cp -c -R` — `cp` clones the same blocks but walks entries one `copyfile(2)` at a time, which took ~4 min on the monorepo. Bash cannot issue a raw syscall, so it is invoked via a short `/usr/bin/python3 -c` `ctypes` shim, with `cp -c -R` kept as a fallback. `clonefile` requires the destination not to exist.
- **The nx cache is shared**, not duplicated — MOP-specific. `NX_CACHE_DIRECTORY` is an absolute path, so every MOP workspace resolves to `~/.cache/nx-mop` (verified against `node_modules/nx/src/utils/cache-directory.js`, which reads the env var and precedes `nx.json`). Prune it with `rm -rf ~/.cache/nx-mop` or `nx reset`; never let it grow per-worktree.
- **`yarn serve` does not parallelize** — MOP-specific. This is a Module Federation monorepo with hardcoded per-app ports (`apps/*/project.json`), so only one MOP workspace can serve at a time — serve serially, in whichever workspace you are reviewing. Tests, builds, lint, and typecheck are worktree-isolated and safe to run concurrently.

**Window naming.** `tmux-dev-layout.sh` names every tmux window `{branch}({repo})` (e.g. `feature/MOP-27970(mop-console-monorepo)`); the repo half comes from the git *common dir*, so it is the real project name even inside a worktree. Window reuse and `wtd` match this name as a **suffix**, so a notification marker prefix (below) never spawns a duplicate window.

**Notifications.** `tmux-agent-notify.sh` is registered globally as Claude Code `Notification` / `Stop` / `UserPromptSubmit` hooks in `claude/.claude/settings.json`, but **self-guards** to act only when the agent's cwd is under `$WORKTREE_ROOT` — this now covers workspaces from both `mwt` and `wt`. It renames the agent's window `🔴 …` (needs input) / `🟢 …` (turn done) and clears the marker on the next prompt, plus fires a macOS notification — **suppressed when you are already looking at that window**, so you are only pinged about tickets elsewhere. "Looking at it" requires all three of window active, session attached, *and* the terminal app frontmost: tmux cannot see that you alt-tabbed to a browser (the window stays active), so the frontmost check — `lsappinfo`, walking the tmux client's process tree up to the terminal GUI — is what keeps the popup from being suppressed exactly when you are away from the machine. The hook **must stay silent on stdout**: Claude Code injects a `Stop`/`UserPromptSubmit` hook's stdout back into the conversation as context. Hook changes take effect only in the *next* `claude` launched.

**Ticket titles.** `worktree-ticket.sh` tags each mwt window with the ticket's JIRA summary as the `@ticket_title` window user option, so `tmux-window-picker.sh` can show it on the window's card without a live JIRA call. `tmux-resurrect`'s default state capture doesn't include custom window options, so a full tmux-server restart (terminal quit + `@continuum-restore`, or a manual `prefix Ctrl-R`) loses it — the window *name* survives (resurrect-native), the title doesn't. Worked around by having `worktree-ticket.sh` also write the title to a sibling file, `$WORKTREE_ROOT/<repo>/<ticket>.title` (next to, not inside, the worktree dir, so it never shows up in that worktree's own `git status`), and `@resurrect-hook-post-restore-all` (`tmux-restore-ticket-titles.sh`) re-applies `@ticket_title` from that file to every worktree window once a restore finishes. `wtd` deletes the sibling file on teardown so it doesn't outlive the worktree.

## Modifying This Repo

- Edit config files in their package directories (e.g., `zsh/.zshrc`, `nvim-stow/.config/nvim/`), not their symlinked locations in `$HOME`.
- After adding a new file to a package, re-run `stow --restow <pkg>` from the repo root to update the symlink.
- Scripts added to `bin/` are automatically available as `~/bin/<script>` after stow; add aliases to `zsh/.zshrc` as needed.
