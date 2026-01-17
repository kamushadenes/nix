---
allowed-tools: MCPSearch, Bash(wt:*), Bash(git:*), Bash(gh:*), AskUserQuestion, Task, TaskOutput
description: Delegate tasks to parallel workers with single consolidated PR
---

## Context

- Repository: !`git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | sed 's/.*github.com[:/]\(.*\)/\1/'`
- Current branch: !`git branch --show-current`
- Working directory: !`pwd`

## Arguments

Parse from $ARGUMENTS:

- `--base <branch>` or `-b <branch>`: Target branch for final PR (default: main)
- `--auto-merge` or `-a`: Auto-merge sub-PRs to parent branch (final PR requires manual merge)
- `--name <feature>` or `-n <feature>`: Override auto-detected feature name

## Configuration

- **MAX_CONCURRENT**: 4 (max parallel workers)
- **POLL_INTERVAL**: 10 seconds
- **HEARTBEAT_TIMEOUT**: 5 minutes (300 seconds)
- **MAX_RETRIES**: 2

## Workflow

### Phase 1: Parse Arguments

1. Check for `--base` / `-b` flag → set target_base (default: "main")
2. Check for `--auto-merge` / `-a` flag → set AUTO_MERGE_SUBS = true (default: false)
3. Check for `--name` / `-n` flag → set FEATURE_NAME override (optional)

### Phase 2: Load MCP Tools

Load task-master tools for task selection:

1. `mcp__task-master-ai__get_tasks` - List all tasks
2. `mcp__task-master-ai__next_task` - Get next available task
3. `mcp__task-master-ai__get_task` - Get task details

### Phase 3: Get All Tasks

1. Get ALL available tasks using `get_tasks`
2. Filter to only `pending` or `ready` tasks (skip `in-progress`, `done`, `blocked`)
3. Build task queue for batch processing
4. If no tasks available, report and exit

### Phase 4: Auto-Detect Feature Name

If no `--name` provided:

1. Analyze task titles for common theme/prefix
2. If all tasks share a parent (e.g., all subtasks of same task), use parent title
3. Otherwise, generate from first task: `feat/<task-id>-<slugified-title>`
4. If ambiguous, confirm with user via AskUserQuestion:

```
AskUserQuestion with:
  questions: [{
    question: "What should the consolidated feature branch be named?",
    header: "Branch",
    multiSelect: false,
    options: [
      { label: "<auto-detected>", description: "Based on task analysis" },
      { label: "feat/<first-task>", description: "Use first task ID" }
    ]
  }]
```

Store as `FEATURE_SLUG` (sanitized for branch names: lowercase, no spaces, no special chars).

### Phase 5: Create Parent Branch

1. Ensure we're on target_base branch:
   ```bash
   git checkout <target_base> && git pull
   ```

2. Create parent branch worktree from target_base:
   ```bash
   wt switch --create "feat/<FEATURE_SLUG>" --yes
   ```

3. Push parent branch to remote:
   ```bash
   cd <parent_worktree> && git push -u origin HEAD
   ```

4. Store `parent_branch = "feat/<FEATURE_SLUG>"`

### Phase 6: Prepare Sub-Branch Worktrees

For each task in the queue:

1. Create sub-branch from parent:
   ```bash
   # Create sub-branch worktree based on parent
   # Use feat/<FEATURE_SLUG>-task/... to avoid git nested branch conflict with feat/<FEATURE_SLUG>
   wt switch --create "feat/<FEATURE_SLUG>-task/<task-id>-<slugified-title>" --base "feat/<FEATURE_SLUG>" --yes
   ```

2. Store: `task.worktree_path = <worktree_path>`
3. Set: `task.target_branch = parent_branch`

### Phase 7: Spawn Workers (Rolling Batch)

Spawn workers in rolling batches of MAX_CONCURRENT:

```python
task_queue = all_tasks[:]  # Copy of all tasks
active_agents = {}  # task_id -> agent_task_id
completed = []
failed = []

# Initial batch: spawn up to MAX_CONCURRENT workers
initial_batch = task_queue[:MAX_CONCURRENT]
task_queue = task_queue[MAX_CONCURRENT:]

# Spawn initial batch in parallel (single message with multiple Task calls)
for task in initial_batch:
    agent_id = Task(
        subagent_type="worker-orchestrator",
        description=f"Task {task.id}: {task.title[:30]}",
        prompt=json.dumps({
            "tasks": [{
                "id": task.id,
                "title": task.title,
                "description": task.description,
                "subtasks": task.subtasks,
                "worktree_path": task.worktree_path
            }],
            "repo": "<owner/repo>",
            "auto_merge": AUTO_MERGE_SUBS,
            "target_branch": parent_branch,
            "config": {
                "poll_interval": 30,
                "heartbeat_timeout": 300,
                "max_retries": 2
            }
        }),
        run_in_background=True
    )
    active_agents[task.id] = agent_id
```

### Phase 8: Monitor Loop (Rolling)

```python
while active_agents or task_queue:
    for task_id, agent_id in list(active_agents.items()):
        result = TaskOutput(task_id=agent_id, block=False, timeout=1000)

        if result.is_complete:
            parsed = json.loads(result.output)
            if parsed.get("completed"):
                completed.extend(parsed["completed"])
            if parsed.get("failed"):
                failed.extend(parsed["failed"])

            del active_agents[task_id]

            # Spawn next worker if queue not empty
            if task_queue:
                next_task = task_queue.pop(0)
                new_agent_id = Task(
                    subagent_type="worker-orchestrator",
                    prompt=json.dumps({...}),  # Same format as above
                    run_in_background=True
                )
                active_agents[next_task.id] = new_agent_id

    # Progress report
    print(f"Active: {len(active_agents)}/{MAX_CONCURRENT}, Completed: {len(completed)}, Failed: {len(failed)}, Queue: {len(task_queue)}")

    sleep(POLL_INTERVAL)
```

### Phase 9: Handle Failures

After all tasks processed:

- If all succeeded: proceed to create final PR
- If some failed: report failures via AskUserQuestion:
  ```
  "X tasks failed. Continue with partial results or abort?"
  Options: "Continue with partial", "Abort"
  ```

### Phase 10: Create Final PR

1. Switch to parent branch worktree:
   ```bash
   cd <parent_worktree>
   ```

2. Pull latest (has all merged sub-PRs):
   ```bash
   git pull
   ```

3. Create final PR to target_base:
   ```bash
   gh pr create --base <target_base> --title "feat: <FEATURE_SLUG>" --body "$(cat <<'EOF'
   ## Summary
   Consolidated PR for: <FEATURE_SLUG>

   ### Completed Tasks
   - Task X: <title> (PR #N)
   - Task Y: <title> (PR #M)

   ### Failed Tasks
   - Task Z: <error> (worktree preserved)

   ---
   Generated with /delegate-tasks-to-pr
   EOF
   )"
   ```

4. Report final PR URL

### Phase 11: Display Results

**Final Summary:**

```
=== Consolidated PR Created ===
PR: <final_pr_url>
Branch: feat/<FEATURE_SLUG> -> <target_base>

Completed Tasks (merged to parent):
  ✓ Task <id>: <title> - PR #N (merged)
  ✓ Task <id>: <title> - PR #M (merged)

Failed Tasks:
  ✗ Task <id>: <title>
    Error: <error>
    Worktree: <path>

Parent Worktree: <parent_worktree_path>
(Preserved until final PR merged)
```

### Phase 12: Cleanup (Optional)

If `--auto-merge` was passed, do NOT auto-merge the final PR. The final PR should always require manual review.

Worktree cleanup:
- Completed tasks with merged sub-PRs: worktrees auto-removed by worker-orchestrator
- Failed tasks: worktrees preserved for investigation
- Parent worktree: preserved until final PR merged

## Begin Execution

Start by parsing arguments, loading MCP tools, getting all available tasks, auto-detecting feature name, then creating the parent branch and sub-branch worktrees.
