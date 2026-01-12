#!/usr/bin/env python3
"""
PreToolUse hook to deny task-master MCP access to worker instances.

Workers should NOT have access to task-master - they communicate via
.orchestrator/task_status file only. The orchestrator handles all
task-master operations based on worker status reports.

Allowed contexts:
- Main Claude instance (no .orchestrator/current_task.md)
- Orchestrator subagents (CLAUDE_ORCHESTRATOR=1 env var)
- Any context without the worker marker file

Denied contexts:
- Worker instances (have .orchestrator/current_task.md AND no CLAUDE_ORCHESTRATOR)
"""
import json
import os
import sys

ORCHESTRATOR_DIR = ".orchestrator"
CURRENT_TASK_FILE = f"{ORCHESTRATOR_DIR}/current_task.md"


def is_worker_instance() -> bool:
    """Check if current instance is a worker (has .orchestrator/current_task.md)."""
    # Workers have the current_task.md file in their worktree
    if not os.path.exists(CURRENT_TASK_FILE):
        return False

    # Orchestrator subagents set CLAUDE_ORCHESTRATOR=1 and should be allowed
    if os.environ.get("CLAUDE_ORCHESTRATOR") == "1":
        return False

    return True


def is_taskmaster_tool(tool_name: str) -> bool:
    """Check if tool is a task-master MCP tool."""
    return tool_name.startswith("mcp__task-master-ai__") or tool_name.startswith("mcp__task_master_ai__")


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)  # Allow on invalid input

    tool_name = input_data.get("tool_name", "")

    # Only check in worker mode
    if not is_worker_instance():
        sys.exit(0)

    # Deny task-master MCP access to workers
    if is_taskmaster_tool(tool_name):
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    "Worker instances cannot access task-master MCP. "
                    "Report progress via .orchestrator/task_status file instead. "
                    "The orchestrator handles all task-master operations."
                )
            }
        }
        print(json.dumps(output))

    # Allow all other tools
    sys.exit(0)


if __name__ == "__main__":
    main()
