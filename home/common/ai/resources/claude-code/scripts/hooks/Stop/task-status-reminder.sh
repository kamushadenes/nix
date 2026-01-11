#!/usr/bin/env bash
# Task Status Reminder Hook - Reminds about in-progress tasks on session end
#
# Checks for tasks still marked as in-progress and reminds the user
# to update their status before ending the session.

set -euo pipefail

# Only run if .taskmaster directory exists
if [[ ! -d ".taskmaster" ]]; then
  exit 0
fi

# Check if task-master CLI is available
if ! command -v npx &>/dev/null; then
  exit 0
fi

# Get in-progress tasks
in_progress=$(timeout 5s npx -y task-master-ai list --status=in-progress 2>/dev/null || echo "")

if [[ -n "$in_progress" && "$in_progress" != "[]" && "$in_progress" != "null" ]]; then
  echo ""
  echo "Tasks still in-progress:"
  echo "$in_progress"
  echo ""
  echo "Consider updating task status before ending session:"
  echo "  - Mark complete: set_task_status --id=N --status=done"
  echo "  - Mark blocked:  set_task_status --id=N --status=blocked"
  echo ""
fi

# Check for uncommitted changes if we have in-progress tasks
if [[ -n "$in_progress" && "$in_progress" != "[]" ]]; then
  if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
    changes=$(git status --porcelain 2>/dev/null || echo "")
    if [[ -n "$changes" ]]; then
      echo "Uncommitted changes detected - consider committing before ending session."
    fi
  fi
fi

exit 0
