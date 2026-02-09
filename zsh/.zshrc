# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
zstyle ':omz:lib:*' aliases no
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.

plugins=(
    # git
    # zsh-completions
    # zsh-autosuggestions
    zsh-syntax-highlighting
    web-search
    jsontools
)
source ~/.bash_profile
#source ~/.zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh
source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# custom scripts
alias crt='zsh ~/bin/checkout-ticket.sh'
alias crc='zsh ~/bin/checkout-config.sh'
alias dpc='zsh ~/bin/deploy-console.sh $(git rev-parse --abbrev-ref HEAD)'
alias dpo='zsh ~/bin/deploy-one.sh $(git rev-parse --abbrev-ref HEAD)'
alias bws='zsh ~/bin/bi-weekly-report.sh'

# Git
alias gp='git push origin $(git rev-parse --abbrev-ref HEAD)'
alias gpf='git push -f origin $(git rev-parse --abbrev-ref HEAD)'
alias gP='git pull origin $(git rev-parse --abbrev-ref HEAD)'
alias gc='git checkout'
alias gco='git commit -m'
alias gca='git commit --amend --no-edit'
alias gs='git status'
alias gbc='echo "$(git rev-parse --abbrev-ref HEAD)" | pbcopy; echo "Copy Branch Name Success!"'

# Yarn
alias ys='yarn serve'
alias yt='yarn test'
alias yb='yarn build-local'
alias yd='yarn download-options'
alias yg='yarn gen:modal "$(git rev-parse --show-prefix)"'

alias tpr='tmux select-pane -T'
alias tvs='tmux split-window -v'
alias ths='tmux split-window -h'
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
eval "$(zoxide init zsh)"
export NVM_DIR="$HOME/.nvm"
export NODE_OPTIONS="--max-old-space-size=8192"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

eval "$(starship init zsh)"


# Secure credential retrieval functions (tokens never exposed in environment)
# Added by init.sh - Do not edit manually
export JENKINS_TOKEN=$(security find-generic-password -a "$USER" -s "jenkins.morrison.express" -w 2>/dev/null)
export JIRA_TOKEN=$(security find-generic-password -a "$USER" -s "morrisonexpress.atlassian.net" -w 2>/dev/null)
export GETDATATOKEN=$(security find-generic-password -a "$USER" -s "getdata.morrison.express" -w 2>/dev/null)

export MOP_CONFIGURATION_PATH="$HOME/project/mop_configuration_files"
export MOP_CONSOLE_PATH="$HOME/project/mop_console"
export MOP_MONOREPO_PATH="$HOME/project/mop-console-monorepo"
export MOP_EPOD_PATH="$HOME/project/mop_epod"

# opencode
export PATH="$HOME/.opencode/bin:$PATH"
export MCP_PATH="$HOME/dotfile-mcp-server"
