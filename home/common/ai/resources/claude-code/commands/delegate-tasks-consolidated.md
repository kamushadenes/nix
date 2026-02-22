---
allowed-tools: Bash(wt:*), Bash(git:*), Bash(gh:*), AskUserQuestion, Task, TaskOutput, TaskList, TaskGet, TaskUpdate
description: Delegate tasks to parallel Claude instances with single consolidated PR
argument-hint: [--base branch] [--auto-merge] [--name feature]
---

## Context

- Repository: !`git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | sed 's/.*github.com[:/]\(.*\)/\1/'`
- Current branch: !`git branch --show-current`
- Working directory: !`pwd`

## Arguments

Parse from $ARGUMENTS:

- `--base <branch>` or `-b <branch>`: Target branch for final PR (default: main)
- `--auto-merge` or `-a`: Auto-merge sub-branches to parent (final PR always requires manual review)
- `--name <feature>` or `-n <feature>`: Override auto-detected feature name

## Workflow

### Phase 1: Task Selection

1. Use `TaskList` to get all available tasks, filter to `pending`
2. If ambiguous feature name, confirm with user via AskUserQuestion

### Phase 2: Create Parent Branch

1. Auto-detect feature name from task titles (or use `--name`)
2. Create parent branch worktree from target_base: `wt switch --create feat/<FEATURE_SLUG>`
3. Push parent branch to remote

### Phase 3: Prepare Sub-Branch Worktrees

For each task:

1. Create sub-branch from parent: `wt switch --create feat/<FEATURE_SLUG>-task/<id>-<title> --base feat/<FEATURE_SLUG>`
2. Store worktree path and target branch for each task

### Phase 4: Create Agent Team

Create an Agent Team, spawning one teammate per task. Each teammate gets a spawn prompt:

```
You are working on task <id>: <title>

## Task Details
<full description and subtasks>

## Instructions (CONSOLIDATED MODE)
1. cd <worktree_path>
2. Work through all subtasks
3. Commit after each subtask using /commit
4. When done: merge to parent via `wt merge --yes --no-remove <parent_branch>`
5. Push parent branch after merge
6. Do NOT create a PR - the lead will create a single consolidated PR

## Target Branch
<parent_branch>
```

### Phase 5: Monitor and Collect Results

Wait for all teammates to complete. Handle merge conflicts by escalating to user.

### Phase 6: Create Final PR

1. Switch to parent branch worktree
2. Push all merged work to remote
3. Create PR from parent branch to target_base:
   ```bash
   gh pr create --base <target_base> --title "feat: <FEATURE_SLUG>" --body "..."
   ```
4. The final PR is NEVER auto-merged (requires manual review)

### Phase 7: Display Results

```
=== Consolidated PR Created ===
PR: <final_pr_url>
Branch: feat/<FEATURE_SLUG> -> <target_base>

Completed Tasks:
  Task <id>: <title> (merged to parent)

Failed Tasks:
  Task <id>: <title>
    Error: <error>
    Worktree: <path>
```

## Begin Execution

Start by parsing arguments, getting all available tasks via TaskList, then creating the branch structure.
