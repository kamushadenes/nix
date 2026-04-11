#!/usr/bin/env bash
# TaskCompleted hook: Verify task completion
#
# Fires when a task is being marked complete.
# Exit 0 to allow completion, exit 2 to prevent with feedback.

set -euo pipefail

# Parse cwd from stdin JSON
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
if [[ -n "$CWD" ]]; then
    cd "$CWD"
fi

# Check for uncommitted changes (tracked modifications + untracked files)
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git rev-parse HEAD &>/dev/null || exit 0  # no commits yet, skip
    has_changes=false
    git diff --quiet HEAD 2>/dev/null || has_changes=true
    [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ] && has_changes=true
    if $has_changes; then
        echo '{"hookSpecificOutput":{"decision":"block","reason":"Cannot mark task complete with uncommitted changes. Commit or stash first."}}'
        exit 2
    fi
fi

# Allow completion
exit 0
