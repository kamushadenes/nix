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

## ClickUp Integration

If `.beads/clickup.yaml` exists, ClickUp sync is enabled for this repo.

**Check on session start:**
```bash
test -f .beads/clickup.yaml && echo "ClickUp linked"
```

**When ClickUp is linked:**
- Run `/clickup-sync` at session start to pull latest tasks from ClickUp
- The Stop hook will remind about unsyced changes
- New beads issues can be pushed to ClickUp via `/clickup-sync`
- Tasks flow bidirectionally: ClickUp ↔ beads

**Field mapping:**
- Beads `external_ref=clickup-{id}` links to ClickUp task
- Priority: 0→urgent, 1→high, 2→normal, 3-4→low
- Status: open→Open, in_progress→In Progress, closed→Closed

## Session Close Checklist

Before ending ANY session:

```
[ ] bd list --status=in_progress  (review active work)
[ ] bd close <completed-ids>      (close finished issues)
[ ] /clickup-sync                 (if .beads/clickup.yaml exists)
[ ] git push                      (beads auto-syncs via daemon)
```

## Enforcement

This rule is enforced. Failure to use beads for task tracking is a workflow violation.
