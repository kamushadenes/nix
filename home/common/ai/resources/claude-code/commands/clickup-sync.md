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

1. PULL: Fetch tasks from ClickUp list
   - For each task, check if bead exists with external_ref=clickup-{task_id}
   - If no match: create new bead with --external-ref=clickup-{task_id}
   - If match: compare timestamps, update bead if ClickUp is newer
   - PULL COMMENTS: For linked beads, fetch ClickUp comments and add missing ones to beads

2. PUSH: Find beads to sync to ClickUp
   - Beads WITH external_ref starting with "clickup-": update the linked task
   - Beads WITHOUT external_ref: create in ClickUp, then bd update --external-ref=clickup-{new_id}
   - PUSH COMMENTS: For linked beads, push bead comments missing from ClickUp
   - CLOSE REASON: When a bead is closed with close_reason, post it as a ClickUp comment prefixed with "[Closed]"

Use external_ref as the primary link. Use last-write-wins for conflicts.
Report what was synced when complete (including comment counts).
```

## Important

- Do not run tools directly - spawn task-agent to do the work
- Task-agent has access to ClickUp MCP tools and bd CLI
- Report the task-agent's results when it completes
