---
allowed-tools: Skill(commit-push-pr), Skill(review), Bash(wt switch:*), Bash(wt remove:*), Bash(git push:*), Bash(git remote:*), Bash(git remote prune:*), Bash(gh pr:*), Bash(cd:*), Bash(direnv allow:*), MCPSearch, mcp__task-master-ai__*, TodoWrite, AskUserQuestion
description: Work on next task with branch and PR workflow
---

# Work on Next Task

Fetch the next available task from task-master, create a feature branch, complete the work, then create a PR.

## Arguments

Parse arguments from $ARGUMENTS:
- `--auto-merge` or `-a`: Automatically merge the PR after creation (uses admin bypass if needed)

## Workflow

### 1. Get Next Task

First, load the MCP tools:

```
MCPSearch with query: "select:mcp__task-master-ai__next_task"
MCPSearch with query: "select:mcp__task-master-ai__expand_task"
MCPSearch with query: "select:mcp__task-master-ai__set_task_status"
MCPSearch with query: "select:mcp__task-master-ai__get_task"
MCPSearch with query: "select:mcp__task-master-ai__update_subtask"
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

### 3. Expand the Task (if needed)

Check if the task already has subtasks. If it does NOT have subtasks:

1. Call `mcp__task-master-ai__set_task_status` with status `in-progress`

2. Call `mcp__task-master-ai__expand_task` with:

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

If subtasks already exist, ensure task status is `in-progress` and skip expansion.

### 4. Display Summary

Before starting work, display a summary to the user:

```
## Task: [task title]

**ID:** [task id]
**Priority:** [priority]
**Branch:** [branch name]
**Description:** [task description]

### Subtasks:
1. [ ] [subtask 1 title]
2. [ ] [subtask 2 title]
3. ...

Starting work...
```

### 5. Work Through Subtasks

For each subtask (skip already completed ones):

1. Display a short summary
2. Use TodoWrite to track progress
3. Complete the subtask work
4. **Commit the changes:**
   Call the Skill tool with:
   - `skill`: "commit"

5. Update subtask status to `done` via `mcp__task-master-ai__update_subtask`

### 6. Mark Task Complete

Once all subtasks are done:

1. Call `mcp__task-master-ai__set_task_status` with status `done`

### 7. Code Review

Run a focused review of all branch changes before creating PR:

```
Skill(skill="review")
```

This automatically reviews branch changes against main using 4 key agents:

- Security vulnerabilities
- Code quality issues
- Missing tests
- Error handling problems

**Important:** Address any Critical or High severity issues found before proceeding. If issues are found, fix them and return to this step until the review passes.

### 8. Create Pull Request

Use the `/commit-push-pr` skill to commit, push, and create the PR:

```
Skill(skill="commit-push-pr")
```

This will:
- Stage and commit any remaining changes
- Push the branch to remote
- Create a PR with a proper description

**Capture the PR number from the output** for the next step.

### 9. Handle Auto-Merge (if requested)

If `--auto-merge` or `-a` was passed:

1. Try standard merge:
   ```bash
   gh pr merge <pr_number> --squash
   ```

2. If blocked by branch protection, try admin bypass:
   ```bash
   gh pr merge <pr_number> --admin --squash
   ```

3. Wait for merge to complete

4. Delete the worktree:
   ```bash
   wt remove <worktree_path>
   ```

5. Clean stale refs:
   ```bash
   git remote prune origin
   ```

If auto-merge NOT requested:
- Log the PR URL
- Inform user they can review and merge manually
- Worktree is preserved until manual merge

### 10. Verify Completion

Confirm:

- Task is marked done in task-master
- PR was created (and merged if --auto-merge)
- Branch was pushed to remote

## Important

- **Branch per task**: Create branches for top-level tasks only, not subtasks
- If the task is blocked or requires user input, ask via AskUserQuestion
- If tests fail, fix them before marking complete
- If the build fails, fix it before marking complete
- Always verify `git push` succeeds before ending
