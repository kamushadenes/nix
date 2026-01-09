# Beads Task Tracking (MANDATORY)

Use `bd` (beads) for ALL task tracking.

## When to Use

- Multi-session work, interruptible tasks, dependencies, discovered work
- Any task beyond a single simple interaction

## Never

- TodoWrite-only for multi-step work (must have backing beads issue)
- Skip status updates or leave sessions without sync
- TODO comments in code (use beads)

## Workflow

1. `bd ready` → `bd update <id> --status=in_progress`
2. TodoWrite for execution steps, beads for parent task
3. `bd close <id>` before session end
4. `bd create --title="..." --type=task|bug|feature` for new work

## Priorities

0=critical, 1=high, 2=medium (default), 3=low, 4=backlog

## ClickUp

If `.beads/clickup.yaml` exists: `/clickup-sync` at session start/end

## Session Close

`bd list --status=in_progress` → `bd close <ids>` → `/clickup-sync` → `git push`
