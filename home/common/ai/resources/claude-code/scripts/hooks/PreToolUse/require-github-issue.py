#!/usr/bin/env python3
"""
PreToolUse hook: Enforce GitHub issue linking for task-master tasks

This hook ensures that tasks in GitHub repositories have linked GitHub issues:

1. add_task: Blocks task creation, requiring a GitHub issue to be created first
2. set_task_status(in-progress): Blocks claiming tasks without [GH:#N] prefix

Only enforces in repositories with GitHub remotes.
"""

import json
import os
import re
import subprocess
import sys
from typing import NoReturn


def get_git_remote() -> str | None:
    """Get the origin remote URL, return None if not a git repo."""
    try:
        result = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return None


def is_github_repo(remote_url: str | None) -> bool:
    """Check if the remote URL is a GitHub repository."""
    if not remote_url:
        return False
    return "github.com" in remote_url


def find_task_by_id(task_id: str) -> dict | None:
    """Find a task by ID in tasks.json."""
    task_file = ".taskmaster/tasks.json"
    if not os.path.exists(task_file):
        return None

    try:
        with open(task_file) as f:
            data = json.load(f)

        for task in data.get("tasks", []):
            if str(task.get("id")) == str(task_id):
                return task
    except (json.JSONDecodeError, OSError):
        pass

    return None


def has_github_issue_prefix(title: str) -> bool:
    """Check if title has [GH:#N] prefix."""
    return bool(re.match(r"\[GH:#\d+\]", title))


def deny(reason: str) -> NoReturn:
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


def allow() -> NoReturn:
    """Exit without output to allow the tool call."""
    sys.exit(0)


def handle_add_task(tool_input: dict) -> None:
    """Block add_task, requiring GitHub issue first."""
    # Check if GitHub repo
    remote_url = get_git_remote()
    if not is_github_repo(remote_url):
        allow()  # Not a GitHub repo, no issue required

    title = tool_input.get("title", "")
    prompt = tool_input.get("prompt", "")

    # If title already has [GH:#N], allow
    if title and has_github_issue_prefix(title):
        allow()

    # Block with helpful message
    task_desc = title if title else (f"(from prompt: {prompt[:50]}...)" if prompt else "(no title)")
    deny(
        f"""Cannot add task "{task_desc}" without a linked GitHub issue.

Create a GitHub issue first:
  gh issue create --title "<task title>" --label task-master

Then add the task with the issue reference in the title:
  Use add_task with title="[GH:#<number>] <task title>"

Or use /next-task which handles this automatically."""
    )


def handle_set_task_status(tool_input: dict) -> None:
    """Block set_task_status(in-progress) without [GH:#N]."""
    # Only check when setting to in-progress
    status = tool_input.get("status", "")
    if status != "in-progress":
        allow()

    task_id = tool_input.get("id", "")
    if not task_id:
        allow()

    # Check if GitHub repo
    remote_url = get_git_remote()
    if not is_github_repo(remote_url):
        allow()  # Not a GitHub repo, no issue required

    # Find the task
    task = find_task_by_id(task_id)
    if not task:
        allow()  # Task not found, allow (might be a subtask)

    title = task.get("title", "")

    # Check for [GH:#N] prefix
    if has_github_issue_prefix(title):
        allow()  # Has issue, allow

    # Block with helpful message
    deny(
        f"""Task "{title}" has no linked GitHub issue.

Create one first:
  gh issue create --title "{title}" --label task-master

Then update the task:
  npx task-master-ai update-task --id={task_id} --title="[GH:#<number>] {title}"

Or use /next-task which handles this automatically."""
    )


def main() -> None:
    # Parse stdin
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        allow()  # Can't parse, allow

    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input") or {}

    if tool_name == "mcp__task-master-ai__add_task":
        handle_add_task(tool_input)
    elif tool_name == "mcp__task-master-ai__set_task_status":
        handle_set_task_status(tool_input)
    else:
        allow()


if __name__ == "__main__":
    main()
