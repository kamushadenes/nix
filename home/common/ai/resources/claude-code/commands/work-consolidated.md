---
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, TodoWrite, Skill
description: Autonomous task execution for consolidated PR workers (merges to parent branch)
---

## Context

- Task file: !`cat .orchestrator/current_task.md 2>/dev/null || echo "No task file found"`
- Current status: !`cat .orchestrator/task_status 2>/dev/null || echo "{}"`

## Your Task

You are a **worker Claude instance** executing an assigned task autonomously as part of a **consolidated PR workflow**.

**IMPORTANT**:
- You do NOT have access to task-master MCP. Report all progress via `.orchestrator/task_progress` file.
- This is a **consolidated workflow**: You merge your work back to the parent branch using `wt merge`, NOT create a PR.
- The orchestrator will create a single final PR from the parent branch to main.

### Workflow

1. **Parse task file**: Read `.orchestrator/current_task.md` for task details, subtasks, and metadata (already shown above)
   - Note the **Target Branch** in metadata - this is the parent branch to merge into
2. **Initialize progress**: Write initial progress to `.orchestrator/task_progress`:
   ```json
   {
     "status": "working",
     "current_subtask": "<first_id>",
     "progress": "starting",
     "completed_subtasks": [],
     "commits": []
   }
   ```
3. **Work through subtasks**:
   - For each subtask:
     - Update `.orchestrator/task_progress` with current subtask and progress
     - Implement the subtask
     - Run tests if applicable (check for test commands in the project)
     - Commit using `/commit`
     - After commit, get the SHA: `git rev-parse HEAD`
     - Update `.orchestrator/task_progress` to add subtask to `completed_subtasks` with commit SHA and notes
4. **Handle errors**:
   - If tests fail: retry up to 3 times with different approaches
   - If still failing: write `FAILED` status with error details and STOP
   - If blocked by unclear requirements: write `STUCK` status with reason and STOP
5. **Merge to Parent Branch**:
   - Parse `target_branch` from the Metadata section in `.orchestrator/current_task.md`
   - Push your branch: `git push -u origin HEAD`
   - Merge to parent branch using worktrunk: `wt merge <target_branch>`
   - This automatically handles the merge and cleanup
6. **Handle Auto-Merge** (if `auto_merge: true` in metadata):
   - The `wt merge` command handles the merge automatically
   - Write final status with `merged: true` and `parent_branch: <target_branch>`
7. **Complete**:
   - Write final progress to `.orchestrator/task_progress`
   - Write final summary to `.orchestrator/task_result` (detailed report for orchestrator)

### Progress File Schema

Always write valid JSON to `.orchestrator/task_progress`:

```json
{
  "status": "working|completed|failed|stuck",
  "current_subtask": "5.1",
  "progress": "human-readable description of current work",
  "completed_subtasks": [
    { "id": "5.1", "commit": "abc123d", "notes": "what was done" }
  ],
  "commits": ["abc123d", "def456e"],
  "final_commit": "ghi789f",
  "parent_branch": "feat/feature-name",
  "merged": true,
  "error": "error description if failed/stuck",
  "notes": "final summary"
}
```

**Note**: The hook automatically:
- Merges your progress into `.orchestrator/task_status`
- Updates the `heartbeat` timestamp
- Adds `current_action` and `last_tool` from tool calls

You write to `task_progress`, the orchestrator reads from `task_status`.

### Result File Schema

On completion (success or failure), write a detailed summary to `.orchestrator/task_result`:

```json
{
  "task_id": "5",
  "title": "Task title",
  "status": "completed|failed|stuck",
  "summary": "Brief 1-2 sentence summary of what was accomplished",
  "actions": [
    "Created user authentication middleware",
    "Added JWT token validation",
    "Fixed login endpoint tests"
  ],
  "files_changed": ["src/auth.ts", "src/middleware.ts", "tests/auth.test.ts"],
  "commits": [
    {"sha": "abc123d", "message": "feat: add JWT validation middleware"},
    {"sha": "def456e", "message": "fix: correct token expiry handling"}
  ],
  "merge": {
    "parent_branch": "feat/feature-name",
    "merged": true
  },
  "error": null,
  "duration_estimate": "~15 minutes"
}
```

### Critical Rules

1. **Always update `.orchestrator/task_progress`** before and after each major action
2. **Write `.orchestrator/task_result`** on completion/failure with detailed summary
3. **Never ask questions** - make reasonable choices and document in commits
4. **Commit frequently** - after each subtask completion
5. **Stop on repeated failures** - 3 retries max, then FAILED status
6. **Include commit SHAs** - orchestrator needs these for tracking
7. **No task-master access** - only use `.orchestrator/` files for communication
8. **Use `wt merge`** - NOT `/commit-push-pr` - this is a consolidated workflow
9. **Never write to task_status directly** - write to task_progress, hook merges it

### Example Progress Updates

Write these to `.orchestrator/task_progress` (hook merges to task_status):

**Starting work:**

```json
{
  "status": "working",
  "current_subtask": "5.1",
  "progress": "analyzing requirements",
  "completed_subtasks": [],
  "commits": []
}
```

**After completing subtask:**

```json
{
  "status": "working",
  "current_subtask": "5.2",
  "progress": "implementing login endpoint",
  "completed_subtasks": [
    {
      "id": "5.1",
      "commit": "abc123d",
      "notes": "Added JWT validation middleware"
    }
  ],
  "commits": ["abc123d"]
}
```

**On completion (merged to parent):**

```json
{"status": "completed", "completed_subtasks": [...], "commits": ["abc123d"], "parent_branch": "feat/feature-name", "merged": true, "notes": "Merged to parent branch"}
```

**On failure:**

```json
{
  "status": "failed",
  "current_subtask": "5.2",
  "completed_subtasks": [
    { "id": "5.1", "commit": "abc123d", "notes": "JWT middleware" }
  ],
  "commits": ["abc123d"],
  "error": "Tests failing after 3 retries - cannot authenticate users"
}
```

### Begin Execution

Parse the task metadata above and begin working through the subtasks. Update `.orchestrator/task_progress` immediately with your initial progress.
