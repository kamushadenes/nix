#!/usr/bin/env bash
# Open Claude Code inside tmux, always bypassing permissions
# Supports multi-account detection via git remote URL or directory path
set -u

#############################################################################
# Account Pattern Definitions (generated from Nix)
#############################################################################
@ACCOUNT_PATTERNS@

#############################################################################
# Account Detection
#############################################################################

_c_detect_account() {
    local target_dir="${1:-$(pwd)}"
    local git_remote=""

    # Try to get git remote URL
    if git -C "$target_dir" rev-parse --git-dir >/dev/null 2>&1; then
        git_remote=$(git -C "$target_dir" remote get-url origin 2>/dev/null || echo "")
    fi

    # Check each account's patterns (generated from Nix)
    @ACCOUNT_DETECTION_LOGIC@

    echo ""
}

_c_set_account_env() {
    local account="$1"
    if [ -n "$account" ]; then
        export CLAUDE_CONFIG_DIR="$HOME/.claude/accounts/$account"
    else
        unset CLAUDE_CONFIG_DIR 2>/dev/null || true
    fi
}

#############################################################################
# Main
#############################################################################

_c_normalize() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-//' | sed 's/-$//'
}

git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Detect and set account
account=$(_c_detect_account "$git_root")
_c_set_account_env "$account"

# Set terminal title
git_folder=$(basename "$git_root")
parent_folder=$(basename "$(dirname "$git_root")")
if [ -n "$account" ]; then
    title="Claude: $parent_folder/$git_folder [$account]"
else
    title="Claude: $parent_folder/$git_folder"
fi
printf '\033]0;%s\007' "$title"

cmd="claude --dangerously-skip-permissions"

if test -n "${TMUX:-}"; then
    if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
        CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" exec $cmd
    else
        exec $cmd
    fi
else
    git_folder_norm=$(_c_normalize "$git_folder")
    parent_folder_norm=$(_c_normalize "$parent_folder")
    session_name="claude-$parent_folder_norm-$git_folder_norm-$(date +%s)"

    if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
        full_cmd="CLAUDE_CONFIG_DIR='$CLAUDE_CONFIG_DIR' $cmd"
    else
        full_cmd="$cmd"
    fi

    exec tmux new-session -s "$session_name" "$full_cmd"
fi
