---
name: codex-update-pr
description: Update PR description based on branch changes against base. Use when the user asks to update the PR description, refresh PR body, or sync PR description with changes.
---

# Update PR Description Workflow

Update an existing PR's description to reflect the current state of branch changes.

## Step 1: Determine base branch

```bash
# Check if PR exists and get its base
gh pr view --json baseRefName,headRefName,title,number,url
```

If no PR exists on the current branch, inform the user and stop.

## Step 2: Gather branch context

```bash
# Get current branch
git rev-parse --abbrev-ref HEAD

# Get base branch from PR
base_branch=$(gh pr view --json baseRefName --jq '.baseRefName')

# Get all commits in the branch
git log --oneline origin/${base_branch}..HEAD

# Get the full diff
git diff origin/${base_branch}...HEAD

# Get changed file stats
git diff origin/${base_branch}...HEAD --stat
```

## Step 3: Delegate to pr-describer agent

Delegate to a pr-describer agent with:
- Current branch name
- Base branch name
- PR title (from `gh pr view`)
- Full diff and commit log
- The user's additional instructions

The agent should generate a PR description following this format:

```markdown
## Summary
- Bullet point summary of changes (1-3 bullets)
- Focus on the "why" not just the "what"

## Changes
- Key changes organized by area/component

## Test plan
- [ ] How to verify these changes work
- [ ] Edge cases considered
```

## Step 4: Update the PR

```bash
gh pr edit --body "<generated description>"
```

## Step 5: Confirm

Report the PR URL and confirm the description was updated.
