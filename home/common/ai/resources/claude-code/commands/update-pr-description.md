---
allowed-tools: Bash(git:*), Bash(gh:*), Task
description: Update PR description based on branch changes against base
---

## Context

- Current branch: !`git branch --show-current`
- PR base: !`gh pr view --json baseRefName -q '.baseRefName' 2>/dev/null || echo "no PR"`

## Steps

1. **Determine base branch:**
   ```bash
   base_branch=$(gh pr view --json baseRefName -q '.baseRefName' 2>/dev/null)
   [ -z "$base_branch" ] && base_branch=$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null)
   [ -z "$base_branch" ] && base_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
   [ -z "$base_branch" ] && base_branch=$(git rev-parse --verify origin/main &>/dev/null && echo main || echo master)
   ```

2. **Get PR info:**
   ```bash
   gh pr view --json number,title,url 2>/dev/null
   ```
   If no PR exists, inform user to create one first.

3. **Delegate to `pr-describer` agent:**

   Use **Task tool** with `subagent_type='pr-describer'`:
   > Generate PR description.
   > Current branch: [current_branch]
   > Base branch: [base_branch]
   > PR title: [title]

4. **Update PR with agent output:**
   ```bash
   gh pr edit --body "$(cat <<'EOF'
   [agent output]
   EOF
   )"
   ```

5. **Confirm:** `Updated PR #[number]. View at: [url]`
