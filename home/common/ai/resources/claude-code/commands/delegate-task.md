---
allowed-tools: MCPSearch, Bash(wt:*), Bash(git:*), Bash(gh:*), Bash(sleep:*), AskUserQuestion
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
- **HEARTBEAT_TIMEOUT**: 5 minutes
- **AUTO_MERGE**: false (unless --auto-merge flag is passed)

## Workflow

### Phase 1: Load MCP Tools

Load required MCP tools:

1. `mcp__task-master-ai__get_tasks` - List all tasks
2. `mcp__task-master-ai__next_task` - Get next available task
3. `mcp__task-master-ai__set_task_status` - Update task status
4. `mcp__task-master-ai__update_subtask` - Update subtask status
5. `mcp__task-master-ai__expand_task` - Expand task into subtasks
6. `mcp__orchestrator__task_worker_spawn` - Spawn worker
7. `mcp__orchestrator__task_worker_status` - Check worker status (includes status_data and result_data)
8. `mcp__orchestrator__task_worker_list` - List all workers
9. `mcp__orchestrator__task_worker_kill` - Kill a worker
10. `mcp__orchestrator__tmux_capture` - Capture tmux window output (fallback for stuck detection)

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

### Phase 4: Initialize Workers

For each selected task:

1. If task has no subtasks, expand it with `expand_task`
2. Get full task data with subtasks
3. Create worktree: `wt switch --create <branch-name>`
   - Branch naming: `<prefix>/<id>-<slugified-title>`
   - The worktree path will be in `~/.worktrees/<branch-name>`
4. Call `task_worker_spawn` with:
   - `task_data`: Full task JSON including subtasks
   - `worktree_path`: Absolute path to worktree
   - `auto_merge`: AUTO_MERGE value
   - `repo`: Repository in owner/repo format
5. Mark task as `in-progress` in task-master
6. Track worker_id, task_id, worktree_path, and synced_subtasks

### Phase 5: Monitor Loop

Enter monitoring loop until all workers complete:

```
active_workers = [...]  # List of active worker tracking objects
synced_subtasks = {}    # Track which subtasks we've synced to task-master

while len(active_workers) > 0:
    for worker in active_workers:
        result = task_worker_status(worker.worker_id)

        if result.status_data:
            # Sync newly completed subtasks to task-master
            for subtask in result.status_data.completed_subtasks:
                if subtask.id not in synced_subtasks[worker.worker_id]:
                    update_subtask(id=subtask.id, status="done", notes=subtask.notes)
                    synced_subtasks[worker.worker_id].add(subtask.id)

        if result.status == "completed":
            status_data = result.status_data
            result_data = result.result_data  # Detailed summary from worker

            # Mark task as done
            set_task_status(task_id, status="done")

            if status_data.merged:
                # PR was auto-merged - clean up worktree
                cleanup_worktree(worker.worktree_path)  # wt remove <path>
                log_success(f"Task {task_id} completed and merged: {status_data.pr_url}")
            else:
                # PR created but not merged - preserve worktree
                log_success(f"Task {task_id} PR created: {status_data.pr_url}")
                log_info(f"Worktree preserved at: {worker.worktree_path}")

            # Store result_data for summary phase
            worker.final_result = result_data
            remove_from_active(worker)
            # NOTE: Do NOT auto-spawn replacement workers

        elif result.status == "failed":
            log_failure(worker)
            if worker.retry_count < 2:
                task_worker_kill(worker.worker_id)
                respawn_worker(worker.task_data)
            else:
                notify_failure(worker)
                remove_from_active(worker)

        elif result.status == "stuck" or is_heartbeat_stale(result):
            # Two-phase stuck detection
            if verify_truly_stuck(worker):
                notify_stuck(worker)
                remove_from_active(worker)

    sleep(30)
```

### Phase 6: Stuck Detection (Two-Phase Tmux Capture)

When heartbeat is older than HEARTBEAT_TIMEOUT and status is "working":

```python
def verify_truly_stuck(worker):
    """Compare two tmux captures 10s apart to detect true stuck state."""
    capture1 = tmux_capture(worker.window_id)
    sleep(10)
    capture2 = tmux_capture(worker.window_id)

    if capture1 == capture2:
        # Output identical = truly stuck
        return True
    else:
        # Output different = still active, hooks just not firing
        return False
```

Only notify user as stuck if both captures are identical.

### Phase 7: Summary

When all workers complete, provide summary using `result_data` from each worker:

**Completed (merged):**

For each task with PR auto-merged:

```
✓ Task <id>: <title>
  Summary: <result_data.summary>
  Actions: <result_data.actions (bullet list)>
  Files: <result_data.files_changed>
  PR: <result_data.pr.url> (merged)
```

**Completed (PR open):**

For each task with PR awaiting review:

```
✓ Task <id>: <title>
  Summary: <result_data.summary>
  Actions: <result_data.actions (bullet list)>
  Files: <result_data.files_changed>
  PR: <result_data.pr.url>
  Worktree: <path> (preserved until merged)
```

**Failed:**

For each failed task:

```
✗ Task <id>: <title>
  Error: <result_data.error or status_data.error>
  Completed: <result_data.actions if any>
  Worktree: <path> (preserved for investigation)
```

**Pending:**

- Count of remaining tasks in task-master queue
- User must run `/delegate-task` again to select more tasks

## Orchestrator Responsibilities

You handle ALL task-master operations - workers only report via `.orchestrator/task_status`:

| Event             | Action                                           |
| ----------------- | ------------------------------------------------ |
| Worker spawned    | Mark task `in-progress` in task-master           |
| Subtask completed | `update_subtask(id, status="done")`              |
| Task completed    | `set_task_status(id, status="done")`             |
| PR merged         | Clean up worktree with `wt remove`               |
| Task failed       | Log error, attempt retry (max 2), or notify user |
| Worker stuck      | Verify with two-phase capture, then notify user  |

## Error Recovery

When a worker fails:

1. Check retry count (max 2 retries)
2. If retriable:
   - Kill the stuck window with `task_worker_kill`
   - The worktree still has partial work - respawn will continue from there
   - Call `task_worker_spawn` again with same task
3. If max retries exceeded:
   - Notify user with error details
   - Preserve worktree for investigation
   - Continue with other workers

## Begin Execution

Start by loading the MCP tools, parsing arguments, getting available tasks, then presenting selection to user.
