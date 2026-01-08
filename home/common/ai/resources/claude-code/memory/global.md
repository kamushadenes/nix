# Global Claude Code Instructions

These rules apply to all projects unless overridden by project-specific CLAUDE.md files.

## Task Tracking with Beads

Use `bd` (beads) for issue/task tracking when `.beads/` directory exists.

**Setup new repos:** Run `/beads-init` to initialize beads with sync-branch workflow.

**Sync-branch workflow (default):**

- Beads data stored on dedicated `beads-sync` branch via git worktree
- Main branch stays clean (no beads commits mixed in)
- Daemon auto-commits/pushes to sync branch in background
- Works with protected branches (PRs required for main)

**Key commands:**

- `bd ready` - Show issues ready to work on
- `bd create --title="..." --type=task|bug|feature --priority=2` - Create issue
- `bd update <id> --status=in_progress` - Claim work
- `bd close <id>` - Mark complete
- `bd sync` - Manual sync (daemon handles automatically)

## Git Commit Rules

Never introduce Claude, Claude Code or Anthropic as Co-Authored-By in git commits, or mention it was used in any way.

## Code Style

- Follow existing project conventions
- Prefer simplicity over cleverness
- Write self-documenting code with minimal comments
