#!/usr/bin/env python3
"""
PreToolUse hook to deny workers from writing directly to task_status.

Workers must write to .orchestrator/task_progress instead.
The worker-heartbeat hook merges task_progress into task_status.

This prevents race conditions between worker writes and heartbeat updates.
"""
import json
import os
import sys

ORCHESTRATOR_DIR = ".orchestrator"
CURRENT_TASK_FILE = f"{ORCHESTRATOR_DIR}/current_task.md"
TASK_STATUS_FILE = f"{ORCHESTRATOR_DIR}/task_status"


def is_worker_instance() -> bool:
    """Check if current instance is a worker."""
    if not os.path.exists(CURRENT_TASK_FILE):
        return False
    # Orchestrator subagents are allowed
    if os.environ.get("CLAUDE_ORCHESTRATOR") == "1":
        return False
    return True


def is_task_status_write(tool_name: str, tool_input: dict) -> bool:
    """Check if this is a write to task_status."""
    if tool_name != "Write":
        return False
    file_path = tool_input.get("file_path", "")
    # Check if writing to task_status (absolute or relative path)
    return file_path.endswith("/task_status") or file_path == ".orchestrator/task_status"


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input") or {}

    # Only check in worker mode
    if not is_worker_instance():
        sys.exit(0)

    # Block direct writes to task_status
    if is_task_status_write(tool_name, tool_input):
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    "Workers cannot write directly to .orchestrator/task_status. "
                    "Write to .orchestrator/task_progress instead. "
                    "The heartbeat hook automatically merges it into task_status."
                )
            }
        }
        print(json.dumps(output))

    sys.exit(0)


if __name__ == "__main__":
    main()
