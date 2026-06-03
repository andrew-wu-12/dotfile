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

`init-base.sh` uses `stow --adopt --restow zsh` and `stow --restow --target="$HOME/bin" bin` — the `--adopt` flag is intentional: it pulls any pre-existing file into the repo before re-linking.

## Initial Setup

```bash
cd ~/dotfile/bin
chmod +x *.sh
./init.sh          # interactive; walks through required + optional tools
source ~/.zshrc
```

`init.sh` orchestrates a sequence of `init-*.sh` sub-scripts. Optional tools (Starship, opencode, Nvim, Tmux, WezTerm, recommended CLI tools) are each prompted individually — pressing Enter skips.

## Credentials

Tokens are stored in macOS Keychain, never in plaintext. `.zshrc` reads them at shell start with `security find-generic-password`. To add or update a token:

```bash
security add-generic-password -a "$USER" -s "<service-name>" -w "<token>" -U
```

Service names: `jenkins.morrison.express`, `morrisonexpress.atlassian.net`, `getdata.morrison.express`.

## Key Scripts in `bin/`

All scripts are symlinked to `~/bin/` and have aliases in `.zshrc`:

- **`checkout-ticket.sh` (`crt <MOP-XXXX>`)** — Queries JIRA for ticket metadata, creates `uat/<parent>` and `feature/<ticket>` branches in `$MOP_MONOREPO_PATH`, opens draft PRs via `gh`. Requires VPN.
- **`checkout-config.sh` (`crc <MOP-XXXX>`)** — Same flow for the `mop_configuration_files` repo; creates dev/uat/prod branches.
- **`deploy-console.sh` (`dpc`)** — Triggers a Jenkins build for `$MOP_CONSOLE_PATH` based on branch prefix (`feature` vs `uat`/`hotfix`).
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
| `JENKINS_TOKEN` | Read from Keychain at shell start |
| `JIRA_TOKEN` | Read from Keychain at shell start |
| `GETDATATOKEN` | Read from Keychain at shell start |
| `SKILL_PATH` | `~/.opencode/skills` (for opencode agent skills) |
| `MCP_PATH` | `~/dotfile-mcp-server` (local MCP server for opencode) |

## Tmux Shortcuts

`prefix` is `Ctrl-B`. Notable bindings:
- `prefix Ctrl-O` — opens opencode in a popup (90% of terminal)
- `prefix Ctrl-G` — opens lazygit in a popup
- Navigation via vim-tmux-navigator: `Ctrl-h/j/k/l` and arrow variants

## opencode Config

`opencode/.opencode/opencode.json` sets the model to `github-copilot/gpt-4o` and loads a local MCP server (`dotfile-mcp-server`) and the `opencode-agent-skills` plugin.

## Modifying This Repo

- Edit config files in their package directories (e.g., `zsh/.zshrc`, `nvim-stow/.config/nvim/`), not their symlinked locations in `$HOME`.
- After adding a new file to a package, re-run `stow --restow <pkg>` from the repo root to update the symlink.
- Scripts added to `bin/` are automatically available as `~/bin/<script>` after stow; add aliases to `zsh/.zshrc` as needed.
