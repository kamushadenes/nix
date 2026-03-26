#!/usr/bin/env bash
# Open Claude Code (or opencode) inside tmux, always bypassing permissions
set -u

_c_normalize() {
	echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-//' | sed 's/-$//'
}

# Parse --opencode flag
use_opencode=false
args=()
for arg in "$@"; do
	if test "$arg" = "--opencode"; then
		use_opencode=true
	else
		args+=("$arg")
	fi
done
set -- "${args[@]+"${args[@]}"}"

git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

git_folder=$(basename "$git_root")
parent_folder=$(basename "$(dirname "$git_root")")

session_name="$parent_folder/$git_folder"

if test "$use_opencode" = true; then
	printf '\033]0;OpenCode: %s/%s\007' "$parent_folder" "$git_folder"
	cmd="opencode"

	if test -n "${TMUX:-}"; then
		exec $cmd "$@"
	else
		git_folder_norm=$(_c_normalize "$git_folder")
		parent_folder_norm=$(_c_normalize "$parent_folder")
		tmux_session="opencode-$parent_folder_norm-$git_folder_norm-$(date +%s)"
		exec tmux new-session -s "$tmux_session" "trap true INT; $cmd $*; echo; echo 'Press Enter to close...'; read _"
	fi
else
	printf '\033]0;Claude: %s/%s\007' "$parent_folder" "$git_folder"
	cmd="claude --dangerously-skip-permissions --name $session_name"

	if test -n "${TMUX:-}"; then
		exec $cmd "$@"
	else
		git_folder_norm=$(_c_normalize "$git_folder")
		parent_folder_norm=$(_c_normalize "$parent_folder")
		tmux_session="claude-$parent_folder_norm-$git_folder_norm-$(date +%s)"
		exec tmux new-session -s "$tmux_session" "trap true INT; $cmd $*; echo; echo 'Press Enter to close...'; read _"
	fi
fi
