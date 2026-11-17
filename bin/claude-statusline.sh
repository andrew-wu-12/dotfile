#!/bin/bash
dir=$(jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null)
gitdir=$(git -C "${dir:-.}" rev-parse --absolute-git-dir 2>/dev/null) || exit 0
[ -s "$gitdir/spec-flow-status" ] && printf '📋 %s\n' "$(head -1 "$gitdir/spec-flow-status")"
exit 0
