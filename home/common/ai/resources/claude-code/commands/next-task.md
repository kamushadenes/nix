---
allowed-tools: Skill(commit), Skill(review), Bash(wt switch:*), Bash(wt merge:*), Bash(git push:*), Bash(git remote:*), Bash(git remote prune:*), Bash(gh issue:*), Bash(cd:*), Bash(direnv allow:*), MCPSearch, mcp__task-master-ai__*, TodoWrite, AskUserQuestion
description: Work on next task with branch and merge workflow
---

# Work on Next Task

Fetch the next available task from task-master, create a feature branch, complete the work, then merge to main.

## Workflow

### 1. Detect GitHub Repository

Before anything else, check if this is a GitHub repository:

```bash
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
```

Extract owner/repo if URL matches `github.com[:/]<owner>/<repo>`.
Store `github_owner` and `github_repo` for use throughout the workflow.
If not a GitHub repo, set `github_available=false` and skip all GitHub steps.

### 2. Get Next Task

First, load the MCP tools:

```
MCPSearch with query: "select:mcp__task-master-ai__next_task"
MCPSearch with query: "select:mcp__task-master-ai__expand_task"
MCPSearch with query: "select:mcp__task-master-ai__set_task_status"
MCPSearch with query: "select:mcp__task-master-ai__get_task"
MCPSearch with query: "select:mcp__task-master-ai__update_task"
```

Then call `mcp__task-master-ai__next_task` to get the highest priority unblocked task.

If no task is available, inform the user and stop.

### 3. Establish GitHub Context

**This step runs every time, even when resuming work on an existing task.**

1. **Check task title for `[GH:#N]` pattern:**

   - If found: Extract issue number and store as `github_issue_number`
   - If NOT found and `github_available=true`: Create GitHub issue (see below)

2. **If creating a new GitHub issue:**

   ```bash
   gh issue create \
     --repo "${github_owner}/${github_repo}" \
     --title "${task_title}" \
     --body "## Task

   ${task_description}

   ---
   _Tracked in task-master. ID: ${task_id}_" \
     --label "task-master"
   ```

   - Extract the issue number from the output
   - Update task title with `[GH:#<issue_number>]` prefix via `mcp__task-master-ai__update_task`

3. **If resuming (task already has subtasks), sync GitHub issue state:**

   - Get current subtasks from task-master
   - For each subtask marked as `done`, ensure the GitHub issue checkbox is ticked
   - Update GitHub issue body to reflect current state (see step 5 for format)

### 4. Create Feature Branch

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

### 5. Expand the Task (if needed)

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

3. **Update GitHub issue with subtasks** (if `github_available=true`):

   Build the issue body with checkboxes for each subtask:

   ```bash
   gh issue edit ${github_issue_number} \
     --repo "${github_owner}/${github_repo}" \
     --body "## Task

   ${task_description}

   ## Subtasks

   - [ ] ${subtask_1_title}
   - [ ] ${subtask_2_title}
   - [ ] ${subtask_3_title}

   ---
   _Tracked in task-master. ID: ${task_id}_"
   ```

If subtasks already exist, ensure task status is `in-progress` and skip expansion.

### 6. Display Summary

Before starting work, display a summary to the user:

```
## Task: [task title]

**ID:** [task id]
**GitHub Issue:** #[issue number] (if available)
**Priority:** [priority]
**Branch:** [branch name]
**Description:** [task description]

### Subtasks:
1. [ ] [subtask 1 title]
2. [ ] [subtask 2 title]
3. ...

Starting work...
```

### 7. Work Through Subtasks

For each subtask (skip already completed ones):

1. Display a short summary
2. Use TodoWrite to track progress
3. Complete the subtask work
4. **Commit the changes:**
   Call the Skill tool with:
   - `skill`: "commit"
   - `args`: "Include #N in the commit message body" (replace N with the actual `github_issue_number`)

   Example: If `github_issue_number` is 42, use `args="Include #42 in the commit message body"`

   If no GitHub issue is linked, omit the `args` parameter.
5. Update subtask status to `done` via `mcp__task-master-ai__update_subtask`
6. **Update GitHub issue to tick the checkbox** (if `github_available=true`):

   Get current issue body and update the checkbox:

   ```bash
   # Get current body, replace unchecked with checked for this subtask
   gh issue edit ${github_issue_number} \
     --repo "${github_owner}/${github_repo}" \
     --body "${updated_body_with_checkbox_ticked}"
   ```

   Replace `- [ ] ${subtask_title}` with `- [x] ${subtask_title}` in the body.

### 8. Mark Task Complete

Once all subtasks are done:

1. Call `mcp__task-master-ai__set_task_status` with status `done`

2. **Close linked GitHub issue** (if `github_available=true`):

   ```bash
   gh issue close ${github_issue_number} \
     --repo "${github_owner}/${github_repo}" \
     --comment "Completed via task-master"
   ```

### 9. Code Review

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

### 10. Commit Changes

Use the `/commit` skill to commit all changes.

Call the Skill tool with:
- `skill`: "commit"
- `args`: "Include #N in the commit message body" (replace N with the actual `github_issue_number`)

Example: If `github_issue_number` is 42, use `args="Include #42 in the commit message body"`

If no GitHub issue is linked, omit the `args` parameter.

### 11. Merge and Push

Merge the feature branch to main and push:

```bash
# Merge to main (squashes, rebases, fast-forwards, removes worktree)
wt merge --yes

# Clean stale refs to prevent corruption issues
git remote prune origin

# Push main to remote
git push
```

If `wt merge` fails due to conflicts, inform the user and stop.

### 12. Verify Completion

Confirm:

- Local main is up to date with remote
- Worktree has been cleaned up
- Task is marked done in task-master
- GitHub issue is closed (if applicable)

## Important

- **Branch per task**: Create branches for top-level tasks only, not subtasks
- **GitHub context persists**: Always check for `[GH:#N]` in task title to recover issue number
- If the task is blocked or requires user input, ask via AskUserQuestion
- If tests fail, fix them before marking complete
- If the build fails, fix it before marking complete
- Always verify `git push` succeeds before ending
- If `wt merge` fails, the user may need to resolve conflicts manually
