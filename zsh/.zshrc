# Put Homebrew on PATH before anything below needs it (zoxide, starship, nvm).
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

zstyle ':omz:lib:*' aliases no

# zsh-syntax-highlighting and zsh-autosuggestions aren't bundled with oh-my-zsh (they come from Homebrew/pacman)
# and are sourced at the bottom of this file; listing them here errors with "plugin not found" when absent.
plugins=(
    web-search
    jsontools
)
source $ZSH/oh-my-zsh.sh

alias crc='zsh ~/bin/checkout-config.sh'
alias mwt='zsh ~/bin/worktree-ticket.sh'
alias wt='zsh ~/bin/worktree-generic.sh'
alias wtd='zsh ~/bin/worktree-done.sh'
alias dpo='zsh ~/bin/deploy-one.sh $(git rev-parse --abbrev-ref HEAD)'
alias bws='zsh ~/bin/bi-weekly-report.sh'
alias tbs='zsh ~/bin/trace-build.sh $(git rev-parse --abbrev-ref HEAD)'
alias dev='zsh ~/bin/tmux-dev-layout.sh'

alias gp='git push origin $(git rev-parse --abbrev-ref HEAD)'
alias gpf='git push -f origin $(git rev-parse --abbrev-ref HEAD)'
alias gP='git pull origin $(git rev-parse --abbrev-ref HEAD)'
alias gc='git checkout'
alias gco='git commit -m'
alias gca='git commit --amend --no-edit'
alias gs='git status'
# pbcopy on macOS; wl-copy (Wayland) or xclip (X11) on Arch, picked via $WAYLAND_DISPLAY.
_clip_copy() {
    if command -v pbcopy &>/dev/null; then
        pbcopy
    elif [ -n "$WAYLAND_DISPLAY" ]; then
        wl-copy
    else
        xclip -selection clipboard
    fi
}
alias gbc='echo "$(git rev-parse --abbrev-ref HEAD)" | _clip_copy; echo "Copy Branch Name Success!"'

alias ys='yarn serve'
alias yt='yarn test'
alias yb='yarn build-local'
alias yd='yarn download-options'
alias ygm='yarn gen:modal "$(git rev-parse --show-prefix)"'
alias ygq='yarn gen:query-page "$(git rev-parse --show-prefix)"'

# Bare `tmux` with a server running would start a NEW numbered session with one window, so `exit` tears the
# session down and drops you out of tmux. Attach to the MRU session instead (same pick as tmux-dev-layout.sh);
# explicit args pass straight through.
tmux() {
  if [[ $# -eq 0 && -z ${TMUX:-} ]] && command tmux has-session 2>/dev/null; then
    command tmux attach -t "$(command tmux list-sessions -F '#{session_last_attached} #{session_name}' \
      | sort -rn | head -1 | cut -d' ' -f2-)"
  else
    command tmux "$@"
  fi
}

alias tpr='tmux select-pane -T'
alias tvs='tmux split-window -v'
alias ths='tmux split-window -h'
eval "$(zoxide init zsh)"
export NVM_DIR="$HOME/.nvm"
export NODE_OPTIONS="--max-old-space-size=8192"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

eval "$(starship init zsh)"

# Tokens are shell variables, deliberately NOT exported: children (Claude Code, MCP servers, npm lifecycle
# scripts, nvim plugins) never inherit them. zsh scripts that `source ~/.zshrc` still see them; anything else
# reads one via ~/bin/cred-read.sh, and a child that needs one gets it as a command-prefix assignment
# (VAR=... cmd). `unset` first drops the export flag a stale parent environment (e.g. an old tmux server) may carry.
# macOS: Keychain (security). Arch: secret-tool (libsecret), assuming a desktop login unlocked the Secret
# Service keyring via PAM.
_read_cred() {
    if command -v security &>/dev/null; then
        security find-generic-password -a "$USER" -s "$1" -w 2>/dev/null
    else
        secret-tool lookup service "$1" account "$USER" 2>/dev/null
    fi
}
unset JENKINS_TOKEN; JENKINS_TOKEN=$(_read_cred "jenkins.morrison.express")
unset JIRA_TOKEN; JIRA_TOKEN=$(_read_cred "morrisonexpress.atlassian.net")
unset GETDATATOKEN; GETDATATOKEN=$(_read_cred "getdata.morrison.express")
# Only codex needs it; its MCP command reads it itself. Unset here so a stale
# export from an older shell or tmux server doesn't keep leaking it.
unset OPENAI_API_KEY

export MOP_CONFIGURATION_PATH="$HOME/project/mop_configuration_files"
export MOP_CONSOLE_PATH="$HOME/project/mop_console"
export MOP_MONOREPO_PATH="$HOME/project/mop-console-monorepo"
export MOP_EPOD_PATH="$HOME/project/mop_epod"
export WORKTREE_ROOT="$HOME/project/worktrees"

# Shared nx cache: an absolute path is used by every workspace (main checkout and each worktree), so tickets
# reuse each other's cached tasks instead of each growing a multi-GB .nx/cache.
export NX_CACHE_DIRECTORY="$HOME/.cache/nx-mop"

export PATH="$HOME/.local/bin:$PATH"

# Untracked, per-person values kept out of this public repo (e.g.
# FORGEJO_HOMELAB_REPO=<owner>/homelab for tmux-task-source-forgejo.sh / hl-* skills).
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# Guarded so a machine that hasn't run init-recommend-cli-tools.sh starts without them instead of erroring.
# zsh-syntax-highlighting must be sourced last: keep these at the end of the file.
[ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] \
    && source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] \
    && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] \
    && source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] \
    && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
