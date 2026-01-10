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

Ask the user which ClickUp account they want to use (e.g., `iniciador`), then create `.beads/clickup.yaml`:

```yaml
account: <account_name>
linked_list:
  list_id: "<clickup_list_id>"
  list_name: "<list_name>"
  space_id: "<space_id>"
  space_name: "<space_name>"
```

The user can find the list_id from the ClickUp URL: `https://app.clickup.com/<team_id>/v/li/<list_id>`

After setup, run `clickup-sync` to perform initial sync.

### If ClickUp IS linked (.beads/clickup.yaml exists):

Run the sync (account is read from the config file):

```bash
clickup-sync -v
```

Report the results when complete.

## Options

- `clickup-sync` - Run sync (account from config)
- `clickup-sync --status` - Show configuration and last sync time
- `clickup-sync --dry-run` - Preview changes (not fully implemented)
- `clickup-sync -v` - Verbose output
- `clickup-sync list` - List all ClickUp tasks
- `clickup-sync list -f "keyword"` - Filter tasks
- `clickup-sync delete <id>` - Delete/archive a task
