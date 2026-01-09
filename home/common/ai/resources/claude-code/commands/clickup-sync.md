---
allowed-tools: Bash(clickup-sync:*), Task
description: Sync ClickUp tasks with beads bidirectionally
---

## Context

- Beads initialized: !`test -d .beads && echo "yes" || echo "no"`
- ClickUp linked: !`test -f .beads/clickup.yaml && echo "yes" || echo "no"`
- Link config: !`cat .beads/clickup.yaml 2>/dev/null || echo "Not linked"`

## Your Task

### If beads is NOT initialized (.beads directory missing):

Tell the user to run `bd init` first to initialize beads in this repository.

### If ClickUp is NOT linked (.beads/clickup.yaml missing):

Spawn task-agent with this prompt for interactive setup:

```
Run ClickUp sync SETUP mode.

1. Use mcp__iniciador-clickup__clickup_get_workspace_hierarchy to list all spaces
2. Present the spaces to the user and ask which one to use
3. Once a space is selected, show folders and lists within that space
4. Ask the user to select a List to link with this repository
5. Write the configuration to .beads/clickup.yaml:
   ```yaml
   linked_list:
     list_id: "<selected_list_id>"
     list_name: "<selected_list_name>"
     space_id: "<selected_space_id>"
     space_name: "<selected_space_name>"
   linked_at: "<current_iso_timestamp>"
   ```
6. After setup, run `clickup-sync` to perform initial sync

This is the setup wizard - be interactive and helpful.
```

### If ClickUp IS linked (.beads/clickup.yaml exists):

Run the deterministic sync script:

```bash
clickup-sync -v
```

Report the results when complete.

## Options

- `clickup-sync` - Run sync (default)
- `clickup-sync --status` - Show configuration and last sync time
- `clickup-sync --dry-run` - Preview changes without syncing (not fully implemented)
- `clickup-sync -v` - Verbose output
