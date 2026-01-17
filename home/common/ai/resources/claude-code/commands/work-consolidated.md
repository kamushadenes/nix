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
   - Update status before merge:
     ```json
     {"status": "merging", "progress": "merging to parent branch"}
     ```
   - Merge to parent branch using worktrunk: `wt merge --yes --no-remove <target_branch>`
   - **If merge fails with non-fast-forward error** (another worker merged first):
     - Pull latest parent: `git fetch origin <target_branch> && git rebase origin/<target_branch>`
     - Push rebased branch: `git push --force-with-lease origin HEAD`
     - Retry merge: `wt merge --yes --no-remove <target_branch>`
     - If still failing after 3 retries, write FAILED status with `"phase": "merge"`
   - After successful merge, push parent branch to remote:
     ```bash
     # Get the parent worktree path and push
     parent_worktree=$(git worktree list | grep "<target_branch>" | cut -d' ' -f1)
     cd "$parent_worktree" && git push origin <target_branch>
     ```
   - **IMPORTANT**: The worktree is NOT automatically removed (--no-remove flag)
     - Write final status files BEFORE the orchestrator cleans up

5b. **Handle Merge Conflicts**:
   - If `wt merge` fails due to conflicts:
     ```json
     {"status": "failed", "error": "Merge conflict with parent branch", "phase": "merge", "conflicting_files": ["list", "of", "files"]}
     ```
   - List conflicting files: `git diff --name-only --diff-filter=U`
   - Do NOT attempt to resolve - orchestrator will handle escalation
   - Worktree preserved for investigation
6. **Handle Auto-Merge** (if `auto_merge: true` in metadata):
   - The `wt merge` command handles the merge automatically
   - Write final status with `merged: true` and `parent_branch: <target_branch>`
7. **Complete**:
   - Write final progress to `.orchestrator/task_progress` with `status: completed`
   - Write final summary to `.orchestrator/task_result` (detailed report for orchestrator)
   - **IMPORTANT**: Write these files BEFORE the orchestrator cleans up the worktree
   - The orchestrator will read these files and then clean up the worktree

### Progress File Schema

Always write valid JSON to `.orchestrator/task_progress`:

```json
{
  "status": "working|merging|completed|failed|stuck",
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
  "phase": "work|merge|push",
  "notes": "final summary"
}
```

**Status Values:**

- `working`: Actively implementing subtasks
- `merging`: Merge operation in progress (don't mark as stuck)
- `completed`: All work done and merged
- `failed`: Unrecoverable error (check `phase` for where)
- `stuck`: Needs human intervention

**Phase Values (for failures):**

- `work`: Failed during implementation/testing
- `merge`: Failed during merge to parent branch
- `push`: Failed pushing to remote

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
8. **Use `wt merge --yes --no-remove`** - NOT `/commit-push-pr` - this is a consolidated workflow
9. **Update status to `merging`** before starting merge operation
10. **Never write to task_status directly** - write to task_progress, hook merges it

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

**Before merging:**

```json
{"status": "merging", "progress": "merging to parent branch", "completed_subtasks": [...], "commits": ["abc123d"]}
```

**On completion (merged to parent):**

```json
{"status": "completed", "completed_subtasks": [...], "commits": ["abc123d"], "parent_branch": "feat/feature-name", "merged": true, "notes": "Merged to parent branch"}
```

**On failure (work phase):**

```json
{
  "status": "failed",
  "current_subtask": "5.2",
  "phase": "work",
  "completed_subtasks": [
    { "id": "5.1", "commit": "abc123d", "notes": "JWT middleware" }
  ],
  "commits": ["abc123d"],
  "error": "Tests failing after 3 retries - cannot authenticate users"
}
```

**On failure (merge phase):**

```json
{
  "status": "failed",
  "phase": "merge",
  "completed_subtasks": [...],
  "commits": ["abc123d", "def456e"],
  "error": "Merge conflict with parent branch",
  "conflicting_files": ["src/auth.ts", "src/middleware.ts"]
}
```

### Begin Execution

Parse the task metadata above and begin working through the subtasks. Update `.orchestrator/task_progress` immediately with your initial progress.
