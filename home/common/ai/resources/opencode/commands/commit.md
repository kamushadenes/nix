---
description: Create a git commit
agent: git-committer
---

Create a git commit for the current changes.

1. Gather git context: status, diff, branch, recent commit style
2. Stage all changes (or specific files if specified by the user)
3. Generate a conventional commit message based on the diff
4. Create the commit

Extra instructions from user: $ARGUMENTS

Mode: commit only (not full PR workflow).
