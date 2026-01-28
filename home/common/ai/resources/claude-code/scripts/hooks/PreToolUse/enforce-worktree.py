#!/usr/bin/env python3
"""
Worktree enforcement hook for task-based development.

Blocks commits on main/master when a task is in-progress, encouraging
the use of worktrees for isolated development.

Exit behavior:
  - Exit 0 with JSON {"hookSpecificOutput": {"permissionDecision": "deny", ...}} = block
  - Exit 0 with no output = allow
"""
import json
import os
import re
import subprocess
import sys


def get_current_branch() -> str:
    """Get the current git branch name."""
    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return result.stdout.strip() if result.returncode == 0 else ""
    except Exception:
        return ""


def is_protected_branch(branch: str) -> bool:
    """Check if the branch is main/master/develop."""
    return branch.lower() in ("main", "master", "develop")


def has_in_progress_tasks() -> bool:
    """Check if there are any in-progress tasks in task-master."""
    if not os.path.isdir(".taskmaster"):
        return False

    try:
        # Read tasks.json directly for speed (avoid npx startup time)
        tasks_file = ".taskmaster/tasks.json"
        if not os.path.isfile(tasks_file):
            return False

        with open(tasks_file) as f:
            data = json.load(f)

        tasks = data.get("tasks", [])
        return any(t.get("status") == "in-progress" for t in tasks)
    except Exception:
        return False


def get_in_progress_task_info() -> str:
    """Get info about in-progress tasks for the error message."""
    try:
        tasks_file = ".taskmaster/tasks.json"
        if not os.path.isfile(tasks_file):
            return ""

        with open(tasks_file) as f:
            data = json.load(f)

        tasks = data.get("tasks", [])
        in_progress = [t for t in tasks if t.get("status") == "in-progress"]

        if not in_progress:
            return ""

        task = in_progress[0]
        task_id = task.get("id", "?")
        title = task.get("title", "Untitled")[:50]
        return f"Task {task_id}: {title}"
    except Exception:
        return "Unknown task"


def deny(reason: str) -> None:
    """Output denial JSON and exit."""
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }
    print(json.dumps(output))
    sys.exit(0)


def main() -> None:
    # Read input from Claude
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)  # Allow if we can't parse input

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input") or {}

    # Only check Bash commands
    if tool_name != "Bash":
        sys.exit(0)

    command = tool_input.get("command", "")
    if not command:
        sys.exit(0)

    # OPTIMIZATION: Check git commit regex BEFORE any subprocess/file I/O
    # This avoids expensive operations for non-commit commands
    if not re.search(r"git\s+commit", command):
        sys.exit(0)

    # OPTIMIZATION: Check if .taskmaster exists before any git operations
    # Most repos don't use task-master, so exit early
    if not os.path.isdir(".taskmaster"):
        sys.exit(0)

    # Now do the expensive checks only for git commit in task-master repos
    branch = get_current_branch()
    if not is_protected_branch(branch):
        sys.exit(0)  # Not on protected branch, allow

    # Check for in-progress tasks
    if not has_in_progress_tasks():
        sys.exit(0)  # No in-progress tasks, allow

    # Block: on protected branch with in-progress task
    task_info = get_in_progress_task_info()
    reason = (
        f"Blocked: Committing to '{branch}' with in-progress task.\n"
        f"\n"
        f"In-progress: {task_info}\n"
        f"\n"
        f"Use a worktree for isolated development:\n"
        f"  wt switch -c feat/<task-id>-<description>\n"
        f"\n"
        f"Or mark the task as done/blocked first:\n"
        f"  set_task_status --id=N --status=done"
    )
    deny(reason)


if __name__ == "__main__":
    main()
