#!/usr/bin/env bash
#
# tmux status helper script
# Outputs: git_branch | 🤖jobs (only shows elements with content)
#
# Usage: tmux-status.sh [pane_current_path]
#

set -euo pipefail

# Orchestrator database path
readonly ORCH_DB="$HOME/.config/orchestrator-mcp/state.db"

# Git options to disable slow fsmonitor
readonly GIT_OPTS=(-c core.useBuiltinFSMonitor=false -c core.fsmonitor=)

# Get git branch for the given directory
get_git_branch() {
    local dir="${1:-.}"

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

    # Check for dirty state
    local dirty=""
    if ! git -C "$dir" "${GIT_OPTS[@]}" diff --quiet 2>/dev/null || \
       ! git -C "$dir" "${GIT_OPTS[@]}" diff --cached --quiet 2>/dev/null; then
        dirty="±"
    fi

    if [[ -n "$branch" ]]; then
        echo " ${branch}${dirty}"
    fi
}

# Get running orchestrator jobs count
get_orchestrator_jobs() {
    if [[ ! -f "$ORCH_DB" ]]; then
        return
    fi

    local count
    count=$(sqlite3 "$ORCH_DB" "SELECT COUNT(*) FROM jobs WHERE status='running'" 2>/dev/null || echo 0)

    if [[ "$count" -gt 0 ]]; then
        echo "🤖${count}"
    fi
}

# Build output with separators
main() {
    local dir="${1:-.}"
    local parts=()

    # Git branch (with icon)
    local git_info
    git_info=$(get_git_branch "$dir")
    if [[ -n "$git_info" ]]; then
        parts+=("$git_info")
    fi

    # Orchestrator jobs
    local jobs_info
    jobs_info=$(get_orchestrator_jobs)
    if [[ -n "$jobs_info" ]]; then
        parts+=("$jobs_info")
    fi

    # Join with separator
    local IFS=" | "
    echo "${parts[*]}"
}

main "$@"
