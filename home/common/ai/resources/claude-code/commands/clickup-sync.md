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

Read .beads/clickup.yaml and .beads/clickup-sync-state.jsonl for context.

1. PULL: Fetch tasks from ClickUp and create/update beads issues
2. PUSH: Find changed beads and update ClickUp tasks

Use last-write-wins for conflict resolution.
Report what was synced when complete.
```

## Important

- Do not run tools directly - spawn task-agent to do the work
- Task-agent has access to ClickUp MCP tools and bd CLI
- Report the task-agent's results when it completes
