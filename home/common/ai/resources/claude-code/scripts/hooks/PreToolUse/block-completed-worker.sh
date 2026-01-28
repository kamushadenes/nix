#!/usr/bin/env bash
#
# PreToolUse hook to block workers from executing further commands
# if the task is already marked as completed.
#
# Converted from Python to bash for faster startup (~5ms vs ~30ms Python).
# This hook runs on EVERY tool call, so startup time matters.

ORCHESTRATOR_DIR=".orchestrator"
CURRENT_TASK_FILE="$ORCHESTRATOR_DIR/current_task.md"
STATUS_FILE="$ORCHESTRATOR_DIR/task_status"
PROGRESS_FILE="$ORCHESTRATOR_DIR/task_progress"

# Read input
input=$(cat)

# Fast path: not a worker if current_task.md doesn't exist
[[ ! -f "$CURRENT_TASK_FILE" ]] && exit 0

# Orchestrator subagents are allowed
[[ "$CLAUDE_ORCHESTRATOR" == "1" ]] && exit 0

# Extract tool name
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

# Always allow Read tool (for cleanup/status reporting)
[[ "$tool_name" == "Read" ]] && exit 0

# Check if task is completed/failed
is_completed() {
    local file="$1"
    [[ ! -f "$file" ]] && return 1
    local status
    status=$(jq -r '.status // empty' "$file" 2>/dev/null)
    [[ "$status" == "completed" || "$status" == "failed" ]]
}

# Check both status files
if is_completed "$STATUS_FILE" || is_completed "$PROGRESS_FILE"; then
    jq -n '{
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": "Task is already marked as completed or failed. No further actions should be taken. Session should end."
        }
    }'
fi

exit 0
