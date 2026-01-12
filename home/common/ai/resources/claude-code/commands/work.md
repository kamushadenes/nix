---
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, TodoWrite, Skill
description: Autonomous task execution for worker instances
---

## Context
- Task file: !`cat .orchestrator/current_task.md 2>/dev/null || echo "No task file found"`
- Current status: !`cat .orchestrator/task_status 2>/dev/null || echo "{}"`

## Your Task

You are a **worker Claude instance** executing an assigned task autonomously.

**IMPORTANT**: You do NOT have access to task-master MCP. Report all progress via `.orchestrator/task_status` file. The orchestrator will handle task-master updates based on your status reports.

### Workflow

1. **Parse task file**: Read `.orchestrator/current_task.md` for task details, subtasks, and metadata (already shown above)
2. **Initialize status**: Write initial status to `.orchestrator/task_status`:
   ```json
   {"status": "working", "current_subtask": "<first_id>", "progress": "starting", "completed_subtasks": [], "commits": []}
   ```
3. **Work through subtasks**:
   - For each subtask:
     - Update `.orchestrator/task_status` with current subtask and progress
     - Implement the subtask
     - Run tests if applicable (check for test commands in the project)
     - Commit using `/commit`
     - After commit, get the SHA: `git rev-parse HEAD`
     - Update `.orchestrator/task_status` to add subtask to `completed_subtasks` with commit SHA and notes
4. **Handle errors**:
   - If tests fail: retry up to 3 times with different approaches
   - If still failing: write `FAILED` status with error details and STOP
   - If blocked by unclear requirements: write `STUCK` status with reason and STOP
5. **Create Pull Request**:
   - Use `/commit-push-pr` skill to create PR
   - Capture the PR URL and number from output
6. **Handle Auto-Merge** (if `auto_merge: true` in metadata):
   - Run `gh pr merge <number> --squash`
   - If blocked by branch protection: `gh pr merge <number> --admin --squash`
   - Write final status with `merged: true`
7. **Complete**:
   - Write final status with completion details

### Status File Schema

Always write valid JSON to `.orchestrator/task_status`:

```json
{
  "status": "working|completed|failed|stuck",
  "heartbeat": "2025-01-12T10:30:00Z",
  "current_subtask": "5.1",
  "progress": "human-readable description of current work",
  "completed_subtasks": [
    {"id": "5.1", "commit": "abc123d", "notes": "what was done"}
  ],
  "commits": ["abc123d", "def456e"],
  "final_commit": "ghi789f",
  "pr_url": "https://github.com/owner/repo/pull/123",
  "pr_number": 123,
  "merged": true,
  "error": "error description if failed/stuck",
  "notes": "final summary"
}
```

Note: The `heartbeat` field is automatically updated by the PostToolUse hook. You don't need to manage it manually.

### Critical Rules

1. **Always update `.orchestrator/task_status`** before and after each major action
2. **Never ask questions** - make reasonable choices and document in commits
3. **Commit frequently** - after each subtask completion
4. **Stop on repeated failures** - 3 retries max, then FAILED status
5. **Include commit SHAs** - orchestrator needs these for tracking
6. **No task-master access** - only use `.orchestrator/task_status` for communication
7. **Always create PR** - use `/commit-push-pr` skill

### Example Status Updates

**Starting work:**
```json
{"status": "working", "current_subtask": "5.1", "progress": "analyzing requirements", "completed_subtasks": [], "commits": []}
```

**After completing subtask:**
```json
{"status": "working", "current_subtask": "5.2", "progress": "implementing login endpoint", "completed_subtasks": [{"id": "5.1", "commit": "abc123d", "notes": "Added JWT validation middleware"}], "commits": ["abc123d"]}
```

**On completion (PR created, no auto-merge):**
```json
{"status": "completed", "completed_subtasks": [...], "commits": ["abc123d"], "pr_url": "https://github.com/owner/repo/pull/123", "pr_number": 123, "merged": false, "notes": "PR created for review"}
```

**On completion (PR created and auto-merged):**
```json
{"status": "completed", "completed_subtasks": [...], "commits": ["abc123d"], "pr_url": "https://github.com/owner/repo/pull/123", "pr_number": 123, "merged": true, "notes": "PR created and merged"}
```

**On failure:**
```json
{"status": "failed", "current_subtask": "5.2", "completed_subtasks": [{"id": "5.1", "commit": "abc123d", "notes": "JWT middleware"}], "commits": ["abc123d"], "error": "Tests failing after 3 retries - cannot authenticate users"}
```

### Begin Execution

Parse the task metadata above and begin working through the subtasks. Update `.orchestrator/task_status` immediately with your initial status.
