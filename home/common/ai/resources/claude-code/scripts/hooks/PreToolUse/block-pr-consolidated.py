#!/usr/bin/env python3
"""
PreToolUse hook to block /commit-push-pr skill when in consolidated workflow mode.

In consolidated workflows, workers should merge to the parent branch using
`wt merge`, NOT create individual PRs using /commit-push-pr. This prevents
creating multiple PRs when the goal is a single consolidated PR.

Detection:
- Check if .orchestrator/current_task.md exists
- Parse target_branch from the metadata section
- If target_branch is set and not main/master/empty, we're in consolidated mode

Blocked actions:
- Skill tool invoking "commit-push-pr"
"""
import json
import os
import re
import sys

ORCHESTRATOR_DIR = ".orchestrator"
CURRENT_TASK_FILE = f"{ORCHESTRATOR_DIR}/current_task.md"


def get_target_branch() -> str | None:
    """Extract target_branch from current_task.md metadata section."""
    if not os.path.exists(CURRENT_TASK_FILE):
        return None

    try:
        with open(CURRENT_TASK_FILE) as f:
            content = f.read()
    except (OSError, IOError):
        return None

    # Look for Target Branch in metadata section
    # Format: "Target Branch: feat/feature-name" or similar
    match = re.search(r"Target Branch:\s*(\S+)", content, re.IGNORECASE)
    if match:
        return match.group(1).strip()

    # Also check for target_branch in JSON-like format
    match = re.search(r'"target_branch"\s*:\s*"([^"]+)"', content)
    if match:
        return match.group(1).strip()

    return None


def is_consolidated_mode() -> bool:
    """Check if we're in consolidated workflow mode."""
    target_branch = get_target_branch()

    if not target_branch:
        return False

    # Not consolidated if targeting main/master or empty
    if target_branch.lower() in ("main", "master", ""):
        return False

    return True


def is_commit_push_pr_skill(tool_name: str, tool_input: dict) -> bool:
    """Check if this is the Skill tool invoking commit-push-pr."""
    if tool_name != "Skill":
        return False

    skill_name = tool_input.get("skill", "")
    return skill_name == "commit-push-pr"


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)  # Allow on invalid input

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input") or {}

    # Only check in consolidated mode
    if not is_consolidated_mode():
        sys.exit(0)

    # Block commit-push-pr skill in consolidated mode
    if is_commit_push_pr_skill(tool_name, tool_input):
        target_branch = get_target_branch()
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    f"Consolidated workflow mode: use `wt merge --yes --no-remove {target_branch}` "
                    "instead of /commit-push-pr. Workers merge to the parent branch, "
                    "and the orchestrator creates a single consolidated PR."
                ),
            }
        }
        print(json.dumps(output))

    # Allow all other tools
    sys.exit(0)


if __name__ == "__main__":
    main()
