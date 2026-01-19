---
allowed-tools: Bash(git:*), Bash(gh:*), Read, Grep, Glob, Task
description: Update PR description based on branch changes against base
---

Update the PR description using the `pr-describer` agent to analyze the FINAL changes this branch introduces.

## Context

- Current branch: !`git branch --show-current`
- PR base (if exists): !`gh pr view --json baseRefName -q '.baseRefName' 2>/dev/null || echo "no PR"`
- Repo default: !`gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null || echo "unknown"`

## Steps

1. **Gather branch context:**

   ```bash
   current_branch=$(git branch --show-current)

   # Determine base branch (priority order):
   # 1. From existing PR - most accurate, PR may target non-default branch
   # 2. From repo's default branch
   # 3. Fallback to main/master detection
   base_branch=$(gh pr view --json baseRefName -q '.baseRefName' 2>/dev/null)
   if [ -z "$base_branch" ]; then
     base_branch=$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null)
   fi
   if [ -z "$base_branch" ]; then
     base_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
   fi
   if [ -z "$base_branch" ]; then
     git rev-parse --verify origin/main &>/dev/null && base_branch="main" || base_branch="master"
   fi
   ```

2. **Check if PR exists:**

   ```bash
   gh pr view --json number,title,body,url 2>/dev/null
   ```

   If no PR exists, inform the user:
   > No PR found for this branch. Create one first with `gh pr create` or `/commit-push-pr`.

3. **Gather diff data:**

   ```bash
   # Changed files
   git diff --name-only ${base_branch}...HEAD

   # Full diff
   git diff ${base_branch}...HEAD

   # Commit messages (for context only)
   git log ${base_branch}..HEAD --oneline
   ```

4. **Delegate to pr-describer agent:**

   Use the **Task tool** with `subagent_type='pr-describer'` to generate the description:

   ```
   Generate a PR description for the following changes:

   Base branch: [base_branch]
   Current title: [existing PR title]

   Changed files:
   [list of changed files]

   Diff:
   [full diff content]

   Commits (for context only, NOT for description):
   [commit list]
   ```

5. **Update the PR with the generated description:**

   ```bash
   gh pr edit --body "$(cat <<'EOF'
   [description from pr-describer agent]
   EOF
   )"
   ```

6. **Confirm to user:**

   > Updated PR description for #[number]. View at: [PR URL]
