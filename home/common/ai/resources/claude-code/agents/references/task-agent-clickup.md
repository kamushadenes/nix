# ClickUp Sync Reference

## Config: `.beads/clickup.yaml`

```yaml
linked_list:
  list_id: "<selected>"
  list_name: "<name>"
  space_id: "<space>"
linked_at: "<timestamp>"
last_sync: null
```

## Setup (no config exists)

1. `mcp__iniciador-clickup__clickup_get_workspace_hierarchy` - list spaces
2. Return structured options for user to choose
3. Drill into space, list folders/lists
4. Write `.beads/clickup.yaml`
5. Run initial pull

## Sync Operations

**Pull from ClickUp:**
1. Read config for `list_id`
2. `mcp__iniciador-clickup__clickup_search` with location filter
3. For each task: check `bd list --json | jq '.[] | select(.external_ref == "clickup-{id}")'`
4. Create missing: `bd create --title="..." --external-ref=clickup-{id}`
5. Update existing if ClickUp newer

**Push to ClickUp:**
1. `bd list --json` to get all beads
2. Has `external_ref`: `mcp__iniciador-clickup__clickup_update_task`
3. No `external_ref`: create in ClickUp, then `bd update <id> --external-ref=clickup-{new_id}`

## Field Mapping

| Beads | ClickUp |
|-------|---------|
| title | name |
| status (open/in_progress/closed) | status (Open/In Progress/Closed) |
| priority (0/1/2/3-4) | priority (urgent/high/normal/low) |
| description | description |
| due | due_date |
| external_ref | stores `clickup-{task_id}` |

## Comments

- Prefix beads→ClickUp with `[Beads]`
- Prefix ClickUp→beads with `[ClickUp]`
- Close reasons: `[Closed] $reason`
- Match by text content to deduplicate
