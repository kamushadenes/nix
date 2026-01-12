---
allowed-tools: MCPSearch, Bash(wt:*), Bash(git:*), Bash(gh:*), AskUserQuestion, Task
description: Delegate tasks to parallel worker Claude instances
---

## Context

- Repository: !`git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | sed 's/.*github.com[:/]\(.*\)/\1/'`
- Current branch: !`git branch --show-current`
- Working directory: !`pwd`

## Arguments

Parse arguments from $ARGUMENTS:

- `--auto-merge` or `-a`: Automatically merge PRs after creation (uses admin bypass if needed)

## Configuration

- **MAX_TASKS_TO_SHOW**: 5
- **POLL_INTERVAL**: 30 seconds
- **HEARTBEAT_TIMEOUT**: 5 minutes (300 seconds)
- **MAX_RETRIES**: 2
- **AUTO_MERGE**: false (unless --auto-merge flag is passed)

## Workflow

### Phase 1: Load MCP Tools

Load task-master tools for task selection:

1. `mcp__task-master-ai__get_tasks` - List all tasks
2. `mcp__task-master-ai__next_task` - Get next available task
3. `mcp__task-master-ai__get_task` - Get task details

### Phase 2: Parse Arguments

Check if `--auto-merge` or `-a` was passed:

- If yes: set AUTO_MERGE = true
- If no: set AUTO_MERGE = false (default)

### Phase 3: Task Selection

1. Get up to MAX_TASKS_TO_SHOW available tasks using `next_task` repeatedly

   - Store each task temporarily
   - Skip tasks that are already `in-progress`

2. Present tasks to user via AskUserQuestion:

   ```
   AskUserQuestion with:
     questions: [{
       question: "Which tasks would you like to delegate to worker instances?",
       header: "Tasks",
       multiSelect: true,
       options: [
         { label: "Task 1: <title>", description: "<brief description>" },
         { label: "Task 2: <title>", description: "<brief description>" },
         ...
       ]
     }]
   ```

3. Parse user selection - only proceed with selected tasks

If user selects "Other" to provide custom input, or selects nothing, ask for clarification.

### Phase 4: Prepare Worktrees

For each selected task:

1. Get full task data with `get_task`
2. Create worktree: `wt switch --create <branch-name>`
   - Branch naming: `feat/<id>-<slugified-title>`
   - The worktree path will be in `~/.worktrees/<branch-name>`
3. Build task object with worktree_path

### Phase 5: Spawn Worker Orchestrator

**Delegate the heavy monitoring work to the worker-orchestrator subagent:**

```python
Task(
    subagent_type="worker-orchestrator",
    description="Orchestrate worker instances",
    prompt=json.dumps({
        "tasks": [
            {
                "id": task.id,
                "title": task.title,
                "description": task.description,
                "subtasks": task.subtasks,
                "worktree_path": worktree_path
            }
            for task in selected_tasks
        ],
        "repo": "<owner/repo from context>",
        "auto_merge": AUTO_MERGE,
        "config": {
            "poll_interval": 30,
            "heartbeat_timeout": 300,
            "max_retries": 2
        }
    })
)
```

The subagent handles:
- Expanding tasks into subtasks if needed
- Spawning worker instances
- Monitoring progress and syncing subtasks
- Stuck detection with two-phase tmux capture
- Retry logic for failed workers
- Cleanup of merged worktrees

### Phase 6: Display Results

When the subagent returns, parse its JSON result and display:

**Completed (merged):**

```
✓ Task <id>: <title>
  Summary: <summary>
  Actions: <actions bullet list>
  Files: <files_changed>
  PR: <pr_url> (merged)
```

**Completed (PR open):**

```
✓ Task <id>: <title>
  Summary: <summary>
  Actions: <actions bullet list>
  Files: <files_changed>
  PR: <pr_url>
  Worktree: <path> (preserved until merged)
```

**Failed:**

```
✗ Task <id>: <title>
  Error: <error>
  Completed: <partial_actions if any>
  Worktree: <path> (preserved for investigation)
```

**Stuck:**

```
⚠ Task <id>: <title>
  Window: <window_id> (still open)
  Worktree: <path>
  Last output: <last_output snippet>
```

**Remaining:**

- Count of remaining tasks in task-master queue
- User must run `/delegate-task` again to select more tasks

## Begin Execution

Start by loading the MCP tools, parsing arguments, getting available tasks, then presenting selection to user.
