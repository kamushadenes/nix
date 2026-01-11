#!/usr/bin/env bash
# Task Context Hook - Shows pending tasks on session start
#
# Displays the highest priority unblocked task from task-master
# to provide immediate context when starting a Claude session.

set -euo pipefail

# Only run if .taskmaster directory exists
if [[ ! -d ".taskmaster" ]]; then
  exit 0
fi

# Check if task-master CLI is available
if ! command -v npx &>/dev/null; then
  exit 0
fi

# Get the next task (highest priority unblocked)
# Use timeout to avoid hanging if task-master is slow
next_task=$(timeout 5s npx -y task-master-ai next 2>/dev/null || echo "")

if [[ -n "$next_task" && "$next_task" != "null" ]]; then
  echo "Next task: $next_task"
fi

# Check for any in-progress tasks
in_progress=$(timeout 5s npx -y task-master-ai list --status=in-progress 2>/dev/null || echo "")

if [[ -n "$in_progress" && "$in_progress" != "[]" ]]; then
  echo "In-progress: $in_progress"
fi

exit 0
