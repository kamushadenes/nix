# Work on Next Task

Fetch the next available task from task-master, expand it into subtasks if needed, complete the work, then commit and push.

## Workflow

### 1. Get Next Task

First, load the MCP tools:

```
MCPSearch with query: "select:mcp__task-master-ai__next_task"
MCPSearch with query: "select:mcp__task-master-ai__expand_task"
MCPSearch with query: "select:mcp__task-master-ai__set_task_status"
```

Then call `mcp__task-master-ai__next_task` to get the highest priority unblocked task.

If no task is available, inform the user and stop.

### 2. Claim the Task

Call `mcp__task-master-ai__set_task_status` with:

- `id`: The task ID
- `status`: `in-progress`

### 3. Expand the Task (if needed)

Check if the task already has subtasks. If it does NOT have subtasks, call `mcp__task-master-ai__expand_task` with:

- `id`: The task ID
- `num`: 3-5 subtasks (use judgment based on complexity)

If subtasks already exist, skip this step.

### 4. Display Summary

Before starting work, display a summary to the user:

```
## Task: [task title]

**ID:** [task id]
**Priority:** [priority]
**Description:** [task description]

### Subtasks:
1. [subtask 1 title]
2. [subtask 2 title]
3. ...

Starting work...
```

### 5. Work Through Subtasks

For each subtask:

1. Display a short summary
2. Use TodoWrite to track progress
3. Complete the subtask work
4. Update subtask status to `done` via `mcp__task-master-ai__update_subtask`

### 6. Mark Task Complete

Once all subtasks are done:

1. Call `mcp__task-master-ai__set_task_status` with status `done`

### 7. Commit and Push

Use the `/commit` command to create a commit, then push:

```bash
git push
```

## Important

- If the task is blocked or requires user input, ask via AskUserQuestion
- If tests fail, fix them before marking complete
- If the build fails, fix it before marking complete
- Always verify `git push` succeeds before ending
