---
allowed-tools: Skill(commit), Skill(review), Bash(wt switch:*), Bash(wt merge:*), Bash(git push:*), Bash(cd:*), Bash(direnv allow:*), MCPSearch, mcp__task-master-ai__*, TodoWrite, AskUserQuestion
description: Work on next task with branch and merge workflow
---

# Work on Next Task

Fetch the next available task from task-master, create a feature branch, complete the work, then merge to main.

## Workflow

### 1. Get Next Task

First, load the MCP tools:

```
MCPSearch with query: "select:mcp__task-master-ai__next_task"
MCPSearch with query: "select:mcp__task-master-ai__expand_task"
MCPSearch with query: "select:mcp__task-master-ai__set_task_status"
MCPSearch with query: "select:mcp__task-master-ai__get_task"
```

Then call `mcp__task-master-ai__next_task` to get the highest priority unblocked task.

If no task is available, inform the user and stop.

### 2. Create Feature Branch

**For top-level tasks only** (not subtasks), create a feature branch:

```bash
# Generate branch name with conventional prefix
# Examples:
#   feat/42-add-user-auth
#   fix/15-resolve-login-bug
#   chore/8-update-dependencies
wt switch --create "<prefix>/<id>-<slugified-title>" --yes

# Allow direnv in the new worktree to ensure environment works
cd <worktree_dir> && direnv allow .
```

Branch naming rules:
- **Prefix**: Choose based on task nature:
  - `feat/` - New features or functionality
  - `fix/` - Bug fixes
  - `chore/` - Maintenance, dependencies, tooling
  - `docs/` - Documentation only
  - `refactor/` - Code refactoring without behavior change
  - `test/` - Adding or updating tests
  - `perf/` - Performance improvements
- **ID**: Use the task ID number (e.g., `42` not `42.1`)
- **Title**: Slugify: lowercase, replace spaces with hyphens, remove special chars
- Keep it short (max ~50 chars total)

If already on a feature branch for this task, skip this step.

### 3. Claim the Task

Call `mcp__task-master-ai__set_task_status` with:

- `id`: The task ID
- `status`: `in-progress`

### 4. Expand the Task (if needed)

Check if the task already has subtasks. If it does NOT have subtasks, call `mcp__task-master-ai__expand_task` with:

- `id`: The task ID
- `num`: 3-5 subtasks (use judgment based on complexity)
- `research`: Set to `true` when any of these apply:
  - Task involves unfamiliar libraries, frameworks, or APIs
  - Task requires integration with external services
  - Task mentions technologies not already present in the codebase
  - Task description is vague and would benefit from research to clarify approach
  - Task involves security, cryptography, or compliance considerations

  Set to `false` when:
  - Task is routine work within well-understood parts of the codebase
  - Task is a simple refactoring, bug fix, or code cleanup
  - All required knowledge is available in existing code or documentation

If subtasks already exist, skip this step.

### 5. Display Summary

Before starting work, display a summary to the user:

```
## Task: [task title]

**ID:** [task id]
**Priority:** [priority]
**Branch:** [branch name]
**Description:** [task description]

### Subtasks:
1. [subtask 1 title]
2. [subtask 2 title]
3. ...

Starting work...
```

### 6. Work Through Subtasks

For each subtask:

1. Display a short summary
2. Use TodoWrite to track progress
3. Complete the subtask work
4. Update subtask status to `done` via `mcp__task-master-ai__update_subtask`

### 7. Mark Task Complete

Once all subtasks are done:

1. Call `mcp__task-master-ai__set_task_status` with status `done`

### 8. Code Review

Run a focused review of all branch changes before committing:

```
Skill(skill="review")
```

This automatically reviews branch changes against main using 4 key agents:
- Security vulnerabilities
- Code quality issues
- Missing tests
- Error handling problems

**Important:** Address any Critical or High severity issues found before proceeding. If issues are found, fix them and return to this step until the review passes.

For comprehensive review with all 9 agents, use `/deep-review` instead.

### 9. Commit Changes

Use the `/commit` skill to commit all changes:

```
Skill(skill="commit")
```

This will analyze changes and create an appropriate commit message.

### 10. Merge and Push

Merge the feature branch to main and push:

```bash
# Merge to main (squashes, rebases, fast-forwards, removes worktree)
wt merge --yes

# Push main to remote
git push
```

If `wt merge` fails due to conflicts, inform the user and stop.

### 11. Verify Completion

Confirm:
- Local main is up to date with remote
- Worktree has been cleaned up
- Task is marked done in task-master

## Important

- **Branch per task**: Create branches for top-level tasks only, not subtasks
- If the task is blocked or requires user input, ask via AskUserQuestion
- If tests fail, fix them before marking complete
- If the build fails, fix it before marking complete
- Always verify `git push` succeeds before ending
- If `wt merge` fails, the user may need to resolve conflicts manually
