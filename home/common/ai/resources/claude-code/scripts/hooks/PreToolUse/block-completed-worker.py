#!/usr/bin/env python3
"""
PreToolUse hook to block workers from executing further commands
if the task is already marked as completed.

This prevents workers from continuing work after they've reported completion,
avoiding unnecessary resource usage and potential conflicts.
"""
import json
import os
import sys

ORCHESTRATOR_DIR = ".orchestrator"
CURRENT_TASK_FILE = f"{ORCHESTRATOR_DIR}/current_task.md"
STATUS_FILE = f"{ORCHESTRATOR_DIR}/task_status"
PROGRESS_FILE = f"{ORCHESTRATOR_DIR}/task_progress"

# Tools that are always allowed (for cleanup/status reporting)
ALLOWED_TOOLS = {"Read"}


def is_worker_instance() -> bool:
    """Check if current instance is a worker."""
    if not os.path.exists(CURRENT_TASK_FILE):
        return False
    # Orchestrator subagents are allowed
    if os.environ.get("CLAUDE_ORCHESTRATOR") == "1":
        return False
    return True


def is_task_completed() -> bool:
    """Check if task status indicates completion."""
    # Check both status and progress files
    for file_path in [STATUS_FILE, PROGRESS_FILE]:
        if os.path.exists(file_path):
            try:
                with open(file_path, "r") as f:
                    data = json.load(f)
                status = data.get("status", "")
                if status in ("completed", "failed"):
                    return True
            except (json.JSONDecodeError, IOError):
                pass
    return False


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")

    # Only check in worker mode
    if not is_worker_instance():
        sys.exit(0)

    # Always allow certain tools
    if tool_name in ALLOWED_TOOLS:
        sys.exit(0)

    # Block if task is already completed
    if is_task_completed():
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    "Task is already marked as completed or failed. "
                    "No further actions should be taken. "
                    "Session should end."
                )
            }
        }
        print(json.dumps(output))

    sys.exit(0)


if __name__ == "__main__":
    main()
