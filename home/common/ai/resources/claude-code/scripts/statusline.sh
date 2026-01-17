#!/usr/bin/env bash
#
# Claude Code statusline script
# Displays: [user@host] directory on branch± | 💰 cost | 🔥 burn_rate | 🧠 context%
# Uses ccusage for cost/context tracking, custom git integration
#

set -euo pipefail

# Catppuccin Macchiato colors
readonly LAVENDER='\033[38;2;183;189;248m'
readonly MAUVE='\033[38;2;198;160;246m'
readonly YELLOW='\033[38;2;238;212;159m'
readonly RESET='\033[0m'

# Git options to disable slow fsmonitor
readonly GIT_OPTS=(-c core.useBuiltinFSMonitor=false -c core.fsmonitor=)

# Read JSON input from Claude Code (save for both our use and ccusage)
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir')

# Get SSH connection info (if remote)
get_ssh_prefix() {
    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        echo "$(whoami)@$(hostname -s) "
    fi
}

# Format directory path (last 2 components, or ~ for home)
format_directory() {
    local dir="$1"

    if [[ "$dir" == "$HOME" ]]; then
        echo "~"
        return
    fi

    # Get last 2 path components for brevity
    local parts
    parts=$(echo "$dir" | tr '/' '\n' | grep -v '^$' | tail -n 2 | paste -sd '/' -)

    if [[ -z "$parts" ]]; then
        echo "/"
    else
        echo "$parts"
    fi
}

# Check if git working tree is dirty (uncommitted changes)
get_git_dirty() {
    local dir="$1"

    # Check if in a git repo first
    if ! git -C "$dir" "${GIT_OPTS[@]}" rev-parse --git-dir >/dev/null 2>&1; then
        return
    fi

    # Check for unstaged or staged changes
    if ! git -C "$dir" "${GIT_OPTS[@]}" diff --quiet 2>/dev/null || \
       ! git -C "$dir" "${GIT_OPTS[@]}" diff --cached --quiet 2>/dev/null; then
        printf " ${YELLOW}±${RESET}"
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

# Parse ccusage output into components
parse_ccusage() {
    local ccusage_output
    # Use globally installed ccusage (via Nix) instead of npx to avoid CPU-intensive downloads
    ccusage_output=$(echo "$input" | ccusage statusline --visual-burn-rate=emoji-text 2>/dev/null) || return

    # Extract model (🤖 Model)
    model_info=$(echo "$ccusage_output" | grep -oE '🤖 [^|]+' | sed 's/ *$//')

    # Extract context (🧠 ...)
    context_info=$(echo "$ccusage_output" | sed -n 's/.*\(🧠 [^|]*\).*/\1/p' | sed 's/ *$//')

    # Extract cost (💰 ...)
    cost_info=$(echo "$ccusage_output" | sed -n 's/.*\(💰 [^|]*\).*/\1/p' | sed 's/ *$//')

    # Extract burn rate (🔥 ...)
    burn_info=$(echo "$ccusage_output" | sed -n 's/.*\(🔥 [^|]*\).*/\1/p' | sed 's/ *$//')
}

# Build and output the statusline
main() {
    local ssh_prefix display_dir git_info git_dirty
    local model_info context_info cost_info burn_info

    ssh_prefix=$(get_ssh_prefix)
    display_dir=$(format_directory "$cwd")
    git_info=$(get_git_branch "$cwd")
    git_dirty=$(get_git_dirty "$cwd")
    parse_ccusage

    # Line 1: directory on branch± | model | context
    printf "%s${LAVENDER}%s${RESET}%s%s" \
        "$ssh_prefix" \
        "$display_dir" \
        "$git_info" \
        "$git_dirty"

    if [[ -n "$model_info" ]]; then
        printf " | %s" "$model_info"
    fi
    if [[ -n "$context_info" ]]; then
        printf " | %s" "$context_info"
    fi

    # Line 2: cost | burn rate
    if [[ -n "$cost_info" || -n "$burn_info" ]]; then
        printf "\n"
        [[ -n "$cost_info" ]] && printf "%s" "$cost_info"
        [[ -n "$burn_info" ]] && printf " | %s" "$burn_info"
    fi
}

main
