#!/usr/bin/env bash
# Open Claude Code inside tmux, always bypassing permissions
set -u

_c_normalize() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-//' | sed 's/-$//'
}

git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

git_folder=$(basename "$git_root")
parent_folder=$(basename "$(dirname "$git_root")")
printf '\033]0;Claude: %s/%s\007' "$parent_folder" "$git_folder"

cmd="claude --dangerously-skip-permissions"

if test -n "${TMUX:-}"; then
    exec $cmd
else
    git_folder_norm=$(_c_normalize "$git_folder")
    parent_folder_norm=$(_c_normalize "$parent_folder")
    session_name="claude-$parent_folder_norm-$git_folder_norm-$(date +%s)"
    exec tmux new-session -s "$session_name" "$cmd"
fi
