#!/usr/bin/env bash
# TeammateIdle hook: Quality gate for Agent Teams
#
# Fires when a teammate finishes and goes idle.
# Exit 0 to allow idle, exit 2 to send feedback and keep working.

set -euo pipefail

# Check for uncommitted changes in the current working directory
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # Check for staged or unstaged changes
    if ! git diff --quiet HEAD 2>/dev/null; then
        echo '{"hookSpecificOutput":{"decision":"block","reason":"You have uncommitted changes. Please commit or stash before finishing."}}'
        exit 2
    fi
fi

# Allow idle
exit 0
