#!/usr/bin/env python3
"""
Suggests using modern CLI tools (rg, fd) instead of grep/find.
Uses additionalContext (Claude Code 2.1.9+) to provide suggestions without blocking.
"""
import json
import re
import sys


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input") or {}
    command = tool_input.get("command", "")

    if tool_name != "Bash" or not isinstance(command, str) or not command:
        sys.exit(0)

    suggestions = []

    # Check for grep usage (but not rg or ripgrep)
    if re.search(r"\bgrep\b", command) and not re.search(
        r"\brg\b|\bripgrep\b", command
    ):
        suggestions.append(
            "Consider using `rg` (ripgrep) instead of `grep` for better performance and .gitignore support."
        )

    # Check for find usage (but not fd)
    if re.search(r"\bfind\b", command) and not re.search(r"\bfd\b", command):
        suggestions.append(
            "Consider using `fd` instead of `find` for better performance and simpler syntax."
        )

    if suggestions:
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow",
                "additionalContext": " ".join(suggestions),
            }
        }
        print(json.dumps(output))

    sys.exit(0)


if __name__ == "__main__":
    main()
