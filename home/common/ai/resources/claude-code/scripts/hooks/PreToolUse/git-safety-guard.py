#!/usr/bin/env python3
"""
Git/filesystem safety guard for Claude Code.

Blocks destructive commands that can lose uncommitted work or delete files.
This hook runs before Bash commands execute and can deny dangerous operations.

Exit behavior:
  - Exit 0 with JSON {"hookSpecificOutput": {"permissionDecision": "deny", ...}} = block
  - Exit 0 with no output = allow

Source: https://github.com/Dicklesworthstone/misc_coding_agent_tips_and_scripts
"""
import json
import re
import sys

# Destructive patterns to block - tuple of (regex, reason)
DESTRUCTIVE_PATTERNS = [
    # Git commands that discard uncommitted changes
    (
        r"git\s+checkout\s+--\s+",
        "git checkout -- discards uncommitted changes permanently. Use 'git stash' first."
    ),
    (
        r"git\s+checkout\s+(?!-b\b)(?!--orphan\b)[^\s]+\s+--\s+",
        "git checkout <ref> -- <path> overwrites working tree. Use 'git stash' first."
    ),
    (
        r"git\s+restore\s+(?!--staged\b)(?!-S\b)",
        "git restore discards uncommitted changes. Use 'git stash' or 'git diff' first."
    ),
    (
        r"git\s+restore\s+.*(?:--worktree|-W\b)",
        "git restore --worktree/-W discards uncommitted changes permanently."
    ),
    # Git reset variants
    (
        r"git\s+reset\s+--hard",
        "git reset --hard destroys uncommitted changes. Use 'git stash' first."
    ),
    (
        r"git\s+reset\s+--merge",
        "git reset --merge can lose uncommitted changes."
    ),
    # Git clean
    (
        r"git\s+clean\s+-[a-z]*f",
        "git clean -f removes untracked files permanently. Review with 'git clean -n' first."
    ),
    # Force operations
    # Note: (?![-a-z]) ensures we only block bare --force, not --force-with-lease or --force-if-includes
    (
        r"git\s+push\s+.*--force(?![-a-z])",
        "Force push can destroy remote history. Use --force-with-lease if necessary."
    ),
    (
        r"git\s+push\s+.*-f\b",
        "Force push (-f) can destroy remote history. Use --force-with-lease if necessary."
    ),
    (
        r"git\s+branch\s+-D\b",
        "git branch -D force-deletes without merge check. Use -d for safety."
    ),
    # Destructive filesystem commands - only block the truly catastrophic ones
    # rm -rf *, rm -rf /, rm -rf /*, rm -rf ~
    (
        r"rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+[*]|rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+[*]",
        "rm -rf * is EXTREMELY DANGEROUS. This command will NOT be executed."
    ),
    (
        r"rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+/\s*$|rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+/\s*$",
        "rm -rf / is EXTREMELY DANGEROUS. This command will NOT be executed."
    ),
    (
        r"rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+/[*]|rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+/[*]",
        "rm -rf /* is EXTREMELY DANGEROUS. This command will NOT be executed."
    ),
    (
        r"rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+~\s*$|rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+~\s*$",
        "rm -rf ~ is EXTREMELY DANGEROUS. This command will NOT be executed."
    ),
    # Git stash drop/clear without explicit permission
    (
        r"git\s+stash\s+drop",
        "git stash drop permanently deletes stashed changes. List stashes first."
    ),
    (
        r"git\s+stash\s+clear",
        "git stash clear permanently deletes ALL stashed changes."
    ),
]

# Patterns that are safe even if they match above (allowlist)
SAFE_PATTERNS = [
    r"git\s+checkout\s+-b\s+",           # Creating new branch
    r"git\s+checkout\s+--orphan\s+",     # Creating orphan branch
    # Unstaging is safe, BUT NOT if --worktree/-W is also present (that modifies working tree)
    r"git\s+restore\s+--staged\s+(?!.*--worktree)(?!.*-W\b)",  # Unstaging only (safe)
    r"git\s+restore\s+-S\s+(?!.*--worktree)(?!.*-W\b)",        # Unstaging short form (safe)
    r"git\s+clean\s+-[a-z]*n[a-z]*",     # Dry run (matches -n, -fn, -nf, -xnf, etc.)
    r"git\s+clean\s+--dry-run",          # Dry run (long form)
]


def _normalize_absolute_paths(cmd):
    """Normalize absolute paths to rm/git for consistent pattern matching.

    Converts /bin/rm, /usr/bin/rm, /usr/local/bin/rm, etc. to just 'rm'.
    Converts /usr/bin/git, /usr/local/bin/git, etc. to just 'git'.

    IMPORTANT: Only normalizes at the START of the command string to avoid
    corrupting paths that appear as arguments (e.g., 'rm /home/user/bin/rm').
    Commands like 'sudo /bin/rm' are NOT normalized, but the destructive
    patterns will still catch them via re.search finding 'rm -rf' in the string.

    Examples:
        /bin/rm -rf /foo -> rm -rf /foo
        /usr/bin/git reset --hard -> git reset --hard
        sudo /bin/rm -rf /foo -> sudo /bin/rm -rf /foo (unchanged, but still caught!)
        rm /home/user/bin/rm -> rm /home/user/bin/rm (unchanged - it's an argument!)
    """
    if not cmd:
        return cmd

    result = cmd

    # Normalize paths to rm/git ONLY at the start of the command
    # This prevents corrupting paths that appear as arguments
    # ^ - must be at start of string
    # /(?:\S*/)* - zero or more path components (e.g., /usr/, /usr/local/)
    # s?bin/rm - matches bin/rm or sbin/rm
    # (?=\s|$) - must be followed by whitespace or end (complete token)
    result = re.sub(r'^/(?:\S*/)*s?bin/rm(?=\s|$)', 'rm', result)

    # Same for git
    result = re.sub(r'^/(?:\S*/)*s?bin/git(?=\s|$)', 'git', result)

    return result


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        # Can't parse input, allow by default
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    # Use 'or {}' to handle both missing key AND explicit null value
    tool_input = input_data.get("tool_input") or {}
    command = tool_input.get("command", "")

    # Only check Bash commands with valid string command
    # Note: isinstance check prevents TypeError if command is int/list/bool
    if tool_name != "Bash" or not isinstance(command, str) or not command:
        sys.exit(0)

    # Store original for error messages, normalize for pattern matching
    # This handles absolute paths like /bin/rm, /usr/bin/git, etc.
    original_command = command
    command = _normalize_absolute_paths(command)

    # Check if command matches any safe pattern first
    for pattern in SAFE_PATTERNS:
        if re.search(pattern, command):
            sys.exit(0)

    # Check if command matches any destructive pattern
    # Note: Case-sensitive matching is intentional - e.g., git branch -D vs -d are different!
    for pattern, reason in DESTRUCTIVE_PATTERNS:
        if re.search(pattern, command):
            output = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": (
                        f"BLOCKED by git_safety_guard.py\n\n"
                        f"Reason: {reason}\n\n"
                        f"Command: {original_command}\n\n"
                        f"If this operation is truly needed, ask the user for explicit "
                        f"permission and have them run the command manually."
                    )
                }
            }
            print(json.dumps(output))
            sys.exit(0)

    # Allow all other commands
    sys.exit(0)


if __name__ == "__main__":
    main()
