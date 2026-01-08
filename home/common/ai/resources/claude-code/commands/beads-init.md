---
allowed-tools: Bash(bd init:*), Bash(bd migrate:*), Bash(bd hooks:*), Bash(bd daemon:*), Bash(bd config:*), Bash(test:*), Bash(ls:*)
description: Initialize beads issue tracking in the current repository
---

## Context

- Current directory: !`pwd`
- Beads already initialized: !`test -d .beads && echo "yes" || echo "no"`
- Git repository: !`test -d .git && echo "yes" || echo "no"`

## Your task

Initialize this repository for beads issue tracking by running the following commands in order:

1. **Skip if already initialized**: If `.beads/` directory exists, inform the user and stop.

2. **Initialize beads**: Run `bd init` to create the `.beads/` directory and database.

3. **Set up sync branch**: Run `bd migrate sync beads-sync` to configure the sync branch workflow.
   - This keeps beads commits on a separate `beads-sync` branch
   - The main branch stays clean (no beads commits mixed in)
   - Works with protected branch workflows (PRs required for main)

4. **Install git hooks**: Run `bd hooks install` to install git hooks for beads integration.

5. **Configure daemon for agent workflows**: Restart the daemon with auto-sync enabled:
   ```
   bd daemon --stop && bd daemon --start --auto-commit --auto-push
   ```
   This ensures beads changes are automatically committed and pushed to the sync branch.

After completion, inform the user that the repository is ready for beads:

**Quick reference:**
- `bd create --title="..." --type=task` - Create an issue
- `bd ready` - Show issues ready to work on
- `bd update <id> --status=in_progress` - Claim work
- `bd close <id>` - Mark complete
- `bd sync` - Manual sync (daemon handles this automatically)

**The sync branch workflow:**
- Beads data lives on `beads-sync` branch (via git worktree)
- Your working branch stays clean of beads commits
- Daemon auto-commits/pushes to sync branch in background
- Run `bd sync --status` to check sync state
