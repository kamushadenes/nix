---
allowed-tools: MCPSearch, Bash(wt:*), Bash(git:*), Bash(gh:*), AskUserQuestion, Task, TaskOutput
description: Delegate tasks to parallel Claude instances via Agent Teams
argument-hint: [--auto-merge]
---

## Context

- Repository: !`git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | sed 's/.*github.com[:/]\(.*\)/\1/'`
- Current branch: !`git branch --show-current`
- Working directory: !`pwd`

## Arguments

Parse arguments from $ARGUMENTS:

- `--auto-merge` or `-a`: Automatically merge PRs after creation

## Workflow

### Phase 1: Task Selection

1. Load task-master MCP tools: `mcp__task-master-ai__get_tasks`, `mcp__task-master-ai__next_task`, `mcp__task-master-ai__get_task`
2. Get up to 5 available tasks using `next_task` repeatedly (skip `in-progress`)
3. Present tasks to user via AskUserQuestion with multiSelect

### Phase 2: Prepare Worktrees

For each selected task:

1. Get full task data with `get_task`
2. Create worktree: `wt switch --create feat/<id>-<slugified-title>`
3. Store worktree path for each task

### Phase 3: Create Agent Team

Create an Agent Team, spawning one teammate per task. Each teammate gets a spawn prompt containing:

- Full task description and subtasks
- Worktree path (cd to it first)
- Instructions: implement, commit using /commit, push, create PR
- Auto-merge flag if set
- Repository context

For each task, the teammate spawn prompt should be:
```
You are working on task <id>: <title>

## Task Details
<full description and subtasks>

## Instructions
1. cd <worktree_path>
2. Work through all subtasks
3. Commit after each subtask using /commit
4. When done, push and create a PR targeting main
5. <If auto-merge: Merge the PR with gh pr merge --squash>

## Repository
<owner/repo>
```

Use delegate mode so the lead focuses on coordination only.

### Phase 4: Monitor and Collect Results

Wait for all teammates to complete. The lead:
- Monitors teammate progress via Teams messaging
- Updates task-master status when teammates complete
- Collects PR URLs and completion summaries

### Phase 5: Display Results

Show aggregated results:

**Completed:**
```
Task <id>: <title>
  PR: <pr_url>
  Files: <count>
```

**Failed:**
```
Task <id>: <title>
  Error: <error>
  Worktree: <path> (preserved)
```

### Phase 6: Sync Main Branch

```bash
git pull --rebase
```

## Begin Execution

Start by loading MCP tools, parsing arguments, getting available tasks, then presenting selection to user.
