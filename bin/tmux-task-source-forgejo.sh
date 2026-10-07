#!/bin/bash
# Task source for tmux-window-picker.sh (TASK_SOURCE_CMD): open issues on the homelab Forgejo repo
# ($FORGEJO_HOMELAB_REPO), worked via worktree-generic.sh (plain branch name, no ticket system).
#   list        number<TAB>title<TAB>open, skipping issues that already have a worktree
#   url <n>     browser link for the issue
#   start <n>   create/open the issue's worktree + window on feature/<n>-<slug> via `wt -n`
# Stateless; the picker caches `list` output.

set -u

WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/project/worktrees}"
FORGEJO_REPO_NAME="homelab"
FORGEJO_BASE="https://git.tailcb6113.ts.net"
TAB=$(printf '\t')
# <owner>/homelab, from the untracked ~/.zshrc.local. Read from the file too,
# since a tmux server started before it existed won't have it in its env.
FORGEJO_OWNER_REPO="${FORGEJO_HOMELAB_REPO:-$(zsh -c 'source ~/.zshrc.local 2>/dev/null; print -r -- "$FORGEJO_HOMELAB_REPO"')}"

get_forgejo_token() {
  security find-generic-password -a "$USER" -s "git.tailcb6113.ts.net" -w 2>/dev/null
}

# Deterministic branch-safe slug from an issue title (lowercase, non-alnum runs -> "-", trimmed, 40 chars).
# Must match between `list`'s worktree-exists check and the branch `start` creates: nothing else links an issue to its branch.
slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-40
}

forgejo_get() {  # $1 = API path under the repo
  local token
  token=$(get_forgejo_token)
  [ -z "$token" ] && return 1
  curl -s -H "Authorization: token $token" "$FORGEJO_BASE/api/v1/repos/$FORGEJO_OWNER_REPO/$1"
}

task_list() {
  forgejo_get "issues?state=open&type=issues&limit=50" \
  | jq -r '.[] | select(.pull_request == null) | [(.number|tostring), (.title | gsub("\t"; " "))] | @tsv' \
  | while IFS="$TAB" read -r number title; do
      [ -z "$number" ] && continue
      [ -d "$WORKTREE_ROOT/$FORGEJO_REPO_NAME/feature-${number}-$(slugify "$title")" ] && continue
      printf '%s\t%s\topen\n' "$number" "$title"
    done
}

task_start() {
  local title
  title=$(forgejo_get "issues/$1" | jq -r '.title // empty')
  if [ -z "$title" ]; then
    echo "Could not fetch issue #$1 from Forgejo." >&2; sleep 1; return 1
  fi
  exec zsh ~/bin/worktree-generic.sh -n "feature/$1-$(slugify "$title")"
}

if [ -z "$FORGEJO_OWNER_REPO" ]; then
  echo "Set FORGEJO_HOMELAB_REPO=<owner>/homelab in ~/.zshrc.local" >&2; exit 1
fi

case "${1:-}" in
  list)  task_list ;;
  url)   [ -n "${2:-}" ] && printf '%s/%s/issues/%s\n' "$FORGEJO_BASE" "$FORGEJO_OWNER_REPO" "$2" ;;
  start) [ -n "${2:-}" ] && task_start "$2" ;;
  *)     echo "usage: ${0##*/} list | url <n> | start <n>" >&2; exit 2 ;;
esac
