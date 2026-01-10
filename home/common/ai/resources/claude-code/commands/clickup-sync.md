---
allowed-tools: Task, MCPSearch, mcp__task-master-ai__*, mcp__iniciador-clickup__*
description: Sync ClickUp tasks with task-master bidirectionally
---

## Context

- Task-master initialized: !`test -d .taskmaster && echo "yes" || echo "no"`
- ClickUp config: !`cat .taskmaster/clickup.yaml 2>/dev/null || echo "Not linked"`

## Your Task

Use the **Task tool** with `subagent_type='task-agent'` to run the sync.

### If task-master is NOT initialized (.taskmaster directory missing):

Tell the user to initialize task-master first:
```bash
# Use the initialize_project MCP tool or run:
npx task-master-ai init
```

### If ClickUp is NOT linked (.taskmaster/clickup.yaml missing):

Ask the user which ClickUp workspace to use, then:

1. Use `mcp__iniciador-clickup__clickup_get_workspace_hierarchy` to browse spaces/lists
2. Let user select the list to sync with
3. Create `.taskmaster/clickup.yaml`:

```yaml
workspace: <workspace_name>
list_id: "<clickup_list_id>"
list_name: "<list_name>"
space_id: "<space_id>"
space_name: "<space_name>"
linked_at: "<ISO 8601 timestamp>"
last_sync: null
```

### If ClickUp IS linked (.taskmaster/clickup.yaml exists):

Run bidirectional sync:

**PULL (ClickUp → task-master):**
1. Read config for `list_id`
2. Use `mcp__iniciador-clickup__clickup_search` to get tasks from the list
3. For each ClickUp task:
   - Check if task-master task exists with matching title or ID in description
   - If no match: use `mcp__task-master-ai__add_task` to create
   - If match: compare dates, update if ClickUp is newer

**PUSH (task-master → ClickUp):**
1. Use `mcp__task-master-ai__get_tasks` to list local tasks
2. For each task-master task:
   - Check if ClickUp task exists (search by title)
   - If no match: use `mcp__iniciador-clickup__clickup_create_task`
   - If match: compare dates, update if task-master is newer

**Status Mapping:**

| Task-Master | ClickUp |
|-------------|---------|
| backlog | "to do", "open" |
| in-progress | "in progress" |
| done | "complete", "closed" |
| blocked | "blocked" |

**Priority Mapping:**

| Task-Master | ClickUp |
|-------------|---------|
| high | 1 (Urgent) or 2 (High) |
| medium | 3 (Normal) |
| low | 4 (Low) |

4. Update `last_sync` in config

Report sync results when complete.
