#!/usr/bin/env bash
# TaskCompleted hook: Verify task completion
#
# Fires when a task is being marked complete.
# Exit 0 to allow completion, exit 2 to prevent with feedback.

set -euo pipefail

# Check for uncommitted changes
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if ! git diff --quiet HEAD 2>/dev/null; then
        echo '{"hookSpecificOutput":{"decision":"block","reason":"Cannot mark task complete with uncommitted changes. Commit or stash first."}}'
        exit 2
    fi
fi

# Allow completion
exit 0
