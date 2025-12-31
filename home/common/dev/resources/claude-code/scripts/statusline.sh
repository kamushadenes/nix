#!/usr/bin/env bash
#
# Claude Code statusline script
# Displays: [user@host] directory on branch | model
#

set -euo pipefail

# Catppuccin Macchiato colors
readonly LAVENDER='\033[38;2;183;189;248m'
readonly MAUVE='\033[38;2;198;160;246m'
readonly RESET='\033[0m'

# Git options to disable slow fsmonitor
readonly GIT_OPTS=(-c core.useBuiltinFSMonitor=false -c core.fsmonitor=)

# Read JSON input from Claude Code
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')

# Get SSH connection info (if remote)
get_ssh_prefix() {
    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        echo "$(whoami)@$(hostname -s) "
    fi
}

# Format directory path (last 4 components, or ~ for home)
format_directory() {
    local dir="$1"

    if [[ "$dir" == "$HOME" ]]; then
        echo "~"
        return
    fi

    # Get last 4 path components
    local parts
    parts=$(echo "$dir" | tr '/' '\n' | grep -v '^$' | tail -n 4 | paste -sd '/' -)

    if [[ -z "$parts" ]]; then
        echo "/"
    else
        echo "$parts"
    fi
}

# Get git branch name (or short SHA if detached)
get_git_branch() {
    local dir="$1"

    # Check if in a git repo
    if ! git -C "$dir" "${GIT_OPTS[@]}" rev-parse --git-dir >/dev/null 2>&1; then
        return
    fi

    # Try branch name first, fall back to short SHA
    local branch
    branch=$(git -C "$dir" "${GIT_OPTS[@]}" branch --show-current 2>/dev/null)

    if [[ -z "$branch" ]]; then
        branch=$(git -C "$dir" "${GIT_OPTS[@]}" rev-parse --short HEAD 2>/dev/null)
    fi

    if [[ -n "$branch" ]]; then
        printf " on ${MAUVE}%s${RESET}" "$branch"
    fi
}

# Build and output the statusline
main() {
    local ssh_prefix display_dir git_info

    ssh_prefix=$(get_ssh_prefix)
    display_dir=$(format_directory "$cwd")
    git_info=$(get_git_branch "$cwd")

    printf "%s${LAVENDER}%s${RESET}%s | %s" \
        "$ssh_prefix" \
        "$display_dir" \
        "$git_info" \
        "$model"
}

main
