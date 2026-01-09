# Beads Task Tracking (MANDATORY)

Use `bd` for all task tracking. See `/beads` skill for full documentation.

## Rules

1. **Use beads for**: multi-session work, dependencies, anything needing persistence
2. **Use TodoWrite for**: single-session execution steps within a beads issue
3. **Never**: track multi-step work only in TodoWrite, leave sessions without closing completed issues

## Quick Reference

```bash
bd ready                          # Find work
bd update <id> --status=in_progress  # Start
bd close <id>                     # Complete
```

Priority: 0=critical, 1=high, 2=medium (default), 3=low, 4=backlog

## ClickUp Integration

If `.beads/clickup.yaml` exists, ClickUp sync is enabled for this repo.

**Check on session start:**
```bash
test -f .beads/clickup.yaml && echo "ClickUp linked"
```

**When ClickUp is linked:**
- Run `/clickup-sync` at session start to pull latest tasks from ClickUp
- The Stop hook will remind about unsynced changes
- New beads issues can be pushed to ClickUp via `/clickup-sync`
- Tasks flow bidirectionally: ClickUp ↔ beads

**Field mapping:**
- Beads `external_ref=clickup-{id}` links to ClickUp task
- Priority: 0→urgent, 1→high, 2→normal, 3-4→low
- Status: open→Open, in_progress→In Progress, closed→Closed

## Session Close

```
[ ] bd close <completed-ids>
[ ] /clickup-sync (if ClickUp linked)
[ ] git push
```
