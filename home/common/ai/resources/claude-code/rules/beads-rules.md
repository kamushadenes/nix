# Beads Task Tracking Rules (MANDATORY)

## Core Requirement

You MUST use `bd` (beads) for ALL task tracking. This is NON-NEGOTIABLE.

## When to Use Beads

ALWAYS create beads issues for:

- Multi-session work (persistence across context boundaries)
- Features, bugs, or tasks that may be interrupted
- Work with dependencies on other tasks
- Discovered work that needs tracking
- ANY task lasting more than a single, simple interaction

## Forbidden Patterns

NEVER do the following:

- Track multi-step work ONLY in TodoWrite without a backing beads issue
- Forget to update beads status when starting/completing work
- Leave sessions without syncing beads (`bd sync` or daemon handles this)
- Create TODO comments in code for tracked work (use beads instead)

## Required Workflow

1. **Starting Work**: Check `bd ready` first, then `bd update <id> --status=in_progress`
2. **During Work**: Use TodoWrite for granular execution steps, but the parent task MUST be in beads
3. **Completing Work**: `bd close <id>` before marking any session complete
4. **Discovering Work**: `bd create --title="..." --type=task|bug|feature` immediately

## Priority Values

Use numeric priorities (0-4), NOT strings:

- 0 (P0): Critical - blocking production
- 1 (P1): High - needed soon
- 2 (P2): Medium - standard work (default)
- 3 (P3): Low - nice to have
- 4 (P4): Backlog - someday/maybe

## Session Close Checklist

Before ending ANY session:

```
[ ] bd list --status=in_progress  (review active work)
[ ] bd close <completed-ids>      (close finished issues)
[ ] git push                      (beads auto-syncs via daemon)
```

## Enforcement

This rule is enforced. Failure to use beads for task tracking is a workflow violation.
