---
description: Sync ClickUp tasks with beads bidirectionally
---

## Context

- Beads initialized: !`test -d .beads && echo "yes" || echo "no"`
- ClickUp linked: !`test -f .beads/clickup.yaml && echo "yes" || echo "no"`
- Link config: !`cat .beads/clickup.yaml 2>/dev/null || echo "Not linked"`
- Last sync: !`grep last_sync .beads/clickup.yaml 2>/dev/null | head -1 || echo "Never"`

## Your Task

You are running the ClickUp sync workflow. Use the Task tool to spawn the `task-agent` with the appropriate prompt based on the context above.

### If beads is NOT initialized (.beads directory missing):

Tell the user to run `bd init` first to initialize beads in this repository.

### If ClickUp is NOT linked (.beads/clickup.yaml missing):

Spawn task-agent with this prompt:

```
Run ClickUp sync SETUP mode (clickup-sync).

1. Use mcp__iniciador-clickup__clickup_get_workspace_hierarchy to list all spaces
2. Present the spaces to the user and ask which one to use
3. Once a space is selected, show folders and lists within that space
4. Ask the user to select a List to link with this repository
5. Write the configuration to .beads/clickup.yaml
6. Run an initial pull to import tasks from the linked list

This is the setup wizard - be interactive and helpful.
```

### If ClickUp IS linked (.beads/clickup.yaml exists):

Spawn task-agent with this prompt:

```
Run ClickUp sync SYNC mode (clickup-sync).

Read .beads/clickup.yaml for the linked list_id.

## Timestamp Comparison (CRITICAL)
Use helper: `python3 ~/.config/nix/config/home/common/ai/resources/claude-code/scripts/helpers/compare-timestamps.py <ts1> <ts2>`
- Returns: "first" (ts1 newer), "second" (ts2 newer), or "equal"
- Handles both Unix ms and ISO 8601 formats automatically
- NEWER timestamp wins - do NOT overwrite newer local changes with older remote state

1. PULL: Fetch tasks from ClickUp list
   - For each task, check if bead exists with external_ref=clickup-{task_id}
   - If NO match: create new bead with --external-ref=clickup-{task_id}
   - If match EXISTS:
     * Get bead's updated_at and ClickUp's date_updated
     * If ClickUp is NEWER: update bead from ClickUp
     * If bead is NEWER or EQUAL: SKIP (do not update bead) - bead state takes precedence
   - PULL COMMENTS: For linked beads, fetch ClickUp comments and add missing ones to beads

2. PUSH: Find beads to sync to ClickUp
   - Beads WITH external_ref starting with "clickup-":
     * Compare timestamps (bead updated_at vs ClickUp date_updated)
     * If bead is NEWER: update ClickUp task with bead's current state (title, description, status, priority)
     * If ClickUp is NEWER: skip (already handled in PULL)
   - Beads WITHOUT external_ref: create in ClickUp, then bd update --external-ref=clickup-{new_id}
   - PUSH COMMENTS: For linked beads, push bead comments missing from ClickUp
   - CLOSE REASON: When a bead is closed with close_reason, post it as a ClickUp comment prefixed with "[Closed]"

Report what was synced when complete (created/updated/skipped counts, comment counts).
```

## Important

- Do not run tools directly - spawn task-agent to do the work
- Task-agent has access to ClickUp MCP tools and bd CLI
- Report the task-agent's results when it completes
