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

Ask the user which ClickUp account they want to use (e.g., `iniciador`), then:

1. Guide them to manually configure `.beads/clickup.yaml`:
   ```yaml
   linked_list:
     list_id: "<clickup_list_id>"
     list_name: "<list_name>"
     space_id: "<space_id>"
     space_name: "<space_name>"
   linked_at: "<current_iso_timestamp>"
   ```

2. They can find the list_id from the ClickUp URL: `https://app.clickup.com/<team_id>/v/li/<list_id>`

3. After setup, run `clickup-sync --account <account>` to perform initial sync

### If ClickUp IS linked (.beads/clickup.yaml exists):

Ask the user which account to use, then run the sync:

```bash
clickup-sync --account <account> -v
```

Report the results when complete.

## Options

- `clickup-sync --account <account>` - Run sync (account required)
- `clickup-sync --account <account> --status` - Show configuration and last sync time
- `clickup-sync --account <account> --dry-run` - Preview changes (not fully implemented)
- `clickup-sync --account <account> -v` - Verbose output
- `clickup-sync --account <account> list` - List all ClickUp tasks
- `clickup-sync --account <account> list -f "keyword"` - Filter tasks
- `clickup-sync --account <account> delete <id>` - Delete/archive a task

## Token Configuration

Tokens are stored as agenix secrets at `~/.claude/secrets/<account>-clickup-token`.

To add a new account:
1. Create the encrypted token in `private/home/common/ai/resources/claude/<account>-clickup-token.age`
2. Add to `private/home/common/ai/resources/claude/secrets.nix`
3. Add agenix mount in `home/common/ai/claude-code.nix`
4. Run `rebuild`
