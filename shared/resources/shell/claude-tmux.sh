#!/usr/bin/env bash
# Claude Code wrapper with tmux session management and account detection
# Delegates worktree management to worktrunk (wt)
#
# Usage: c [OPTIONS] [COMMAND] [ARGS...]
#
# OPTIONS:
#   -a <account>         - Override automatic account detection
#   -h                   - Use Happy wrapper instead of claude directly
#
# COMMANDS:
#   c                    - Start tmux+claude in current directory
#   c <args>             - Pass args to claude
#   c work|w <branch>    - Create worktree via wt, start claude there
#   c list               - List worktrees (delegates to wt list)
#   c clean|x            - Remove worktrees (delegates to wt remove)
#   c help               - Show help
#
# TMUX:
#   If not already in a tmux session, spawns a new tmux session with a unique
#   name based on the git repository (claude-<parent>-<repo>-<timestamp>).
#   If already in tmux, runs claude directly.
#
# MULTI-ACCOUNT:
#   Automatically detects account based on git remote URL or directory path.
#   Sets CLAUDE_CONFIG_DIR to use account-specific MCP servers.
#   Use -a to override automatic detection.

set -u

# Global options
_C_ACCOUNT_OVERRIDE=""
_C_USE_HAPPY="false"

# Parse global options
while [ $# -gt 0 ]; do
    case "$1" in
        -a)
            if [ $# -lt 2 ]; then
                echo "Error: -a requires an account name"
                exit 1
            fi
            _C_ACCOUNT_OVERRIDE="$2"
            shift 2
            ;;
        -h)
            _C_USE_HAPPY="true"
            shift
            ;;
        *)
            break
            ;;
    esac
done

#############################################################################
# Account Pattern Definitions (generated from Nix)
#############################################################################
@ACCOUNT_PATTERNS@

#############################################################################
# Account Detection Functions
#############################################################################

# Detect account from git remote URL or directory path
# Usage: _c_detect_account [directory]
# Returns: account name or empty string
_c_detect_account() {
    local target_dir="${1:-$(pwd)}"
    local git_remote=""

    # Check for manual override first
    if [ -n "$_C_ACCOUNT_OVERRIDE" ]; then
        echo "$_C_ACCOUNT_OVERRIDE"
        return 0
    fi

    # Try to get git remote URL
    if git -C "$target_dir" rev-parse --git-dir >/dev/null 2>&1; then
        git_remote=$(git -C "$target_dir" remote get-url origin 2>/dev/null || echo "")
    fi

    # Check each account's patterns (generated from Nix)
    @ACCOUNT_DETECTION_LOGIC@

    # No match - use default
    echo ""
}

# Set CLAUDE_CONFIG_DIR environment variable for detected account
_c_set_account_env() {
    local account="$1"
    if [ -n "$account" ]; then
        export CLAUDE_CONFIG_DIR="$HOME/.claude/accounts/$account"
    else
        unset CLAUDE_CONFIG_DIR 2>/dev/null || true
    fi
}

# Build command (claude or happy) with args
_c_build_cmd() {
    if [ "$_C_USE_HAPPY" = "true" ]; then
        echo "happy"
    else
        echo "claude"
    fi
}

#############################################################################
# Commands
#############################################################################

# Helper: normalize string for directory/session name
_c_normalize() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-//' | sed 's/-$//'
}

# Default: run claude in current directory with account detection
_c_default() {
    local git_root
    git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

    # Detect and set account
    local account
    account=$(_c_detect_account "$git_root")
    _c_set_account_env "$account"

    # Set terminal title
    local git_folder parent_folder title
    git_folder=$(basename "$git_root")
    parent_folder=$(basename "$(dirname "$git_root")")
    if [ -n "$account" ]; then
        title="Claude: $parent_folder/$git_folder [$account]"
    else
        title="Claude: $parent_folder/$git_folder"
    fi
    printf '\033]0;%s\007' "$title"

    # Build command (claude or happy)
    local cmd
    cmd=$(_c_build_cmd)

    if test -n "${TMUX:-}"; then
        # Already in tmux - run command directly (env var already exported)
        exec $cmd "$@"
    else
        # Normalized versions for session name
        local git_folder_norm parent_folder_norm timestamp session_name full_cmd
        git_folder_norm=$(_c_normalize "$git_folder")
        parent_folder_norm=$(_c_normalize "$parent_folder")

        # Generate session name: claude-<parent>-<git_folder>-<timestamp>
        timestamp=$(date +%s)
        session_name="claude-$parent_folder_norm-$git_folder_norm-$timestamp"

        # Build full command with CLAUDE_CONFIG_DIR if account-specific
        if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
            full_cmd="CLAUDE_CONFIG_DIR='$CLAUDE_CONFIG_DIR' $cmd $*"
        else
            full_cmd="$cmd $*"
        fi

        # Start tmux and run command inside (exit tmux when command exits)
        exec tmux new-session -s "$session_name" "$full_cmd"
    fi
}

# Work: create worktree via wt and start claude
_c_worktree() {
    if [ $# -lt 1 ]; then
        echo "Usage: c work <branch>"
        return 1
    fi

    local branch="$1"
    shift

    # Detect account from current directory (before switching)
    local account
    account=$(_c_detect_account "$(pwd)")

    # Build execute command with account env
    local cmd execute_cmd
    cmd=$(_c_build_cmd)
    if [ -n "$account" ]; then
        execute_cmd="CLAUDE_CONFIG_DIR=$HOME/.claude/accounts/$account $cmd"
    else
        execute_cmd="$cmd"
    fi

    # Delegate to worktrunk
    # -c = create if doesn't exist
    # --execute = run command after switching
    wt switch -c --execute="$execute_cmd" "$branch"
}

# List: delegate to wt list
_c_list() {
    wt list "$@"
}

# Clean: delegate to wt remove
_c_clean() {
    wt remove "$@"
}

# Help
_c_help() {
    cat <<'EOF'
c - Claude Code wrapper with tmux and account detection

USAGE:
  c [OPTIONS] [COMMAND] [ARGS...]

OPTIONS:
  -a <account>         Override automatic account detection
  -h                   Use Happy wrapper instead of claude directly

COMMANDS:
  c                    Start tmux+claude in current directory
  c <args>             Pass args to claude (e.g., c --help, c -p 'prompt')
  c work|w <branch>    Create worktree for branch, start claude there
  c list               List worktrees (via wt list)
  c clean|x            Remove worktrees (via wt remove)
  c help               Show this help

TMUX:
  If not already in a tmux session, spawns a new session with a unique name
  (claude-<parent>-<repo>-<timestamp>). If already in tmux, runs claude directly.

MULTI-ACCOUNT:
  Automatically detects account based on git remote URL or directory path.
  Sets CLAUDE_CONFIG_DIR to use account-specific MCP servers.
  Use -a to override: c -a iniciador

HAPPY WRAPPER:
  By default, 'c' runs claude directly.
  Use -h to run via Happy wrapper for mobile/web access.

EXAMPLES:
  c                      Start claude
  c -h                   Start claude via Happy wrapper
  c -a iniciador         Start with iniciador account
  c w feature-x          Create worktree for feature-x, start claude
  c list                 Show all worktrees
  c clean                Interactive worktree cleanup

WORKTREE PATH:
  Worktrees are managed by worktrunk (wt).
  Default path: ../worktrees/<repo>/<branch>/
EOF
}

#############################################################################
# Main dispatch
#############################################################################
case "${1:-}" in
    "")
        _c_default
        ;;
    work|w)
        shift
        _c_worktree "$@"
        ;;
    list)
        shift
        _c_list "$@"
        ;;
    clean|x)
        shift
        _c_clean "$@"
        ;;
    help)
        _c_help
        ;;
    *)
        # Pass through to claude (existing behavior)
        _c_default "$@"
        ;;
esac
