---
allowed-tools: Bash(git:*), Bash(gh:*), Read, Grep, Glob
description: Update PR description based on branch changes against base
---

Update the PR description to accurately reflect the FINAL changes this branch introduces against the base branch.

## Context

- Current branch: !`git branch --show-current`
- Default branch: !`gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null || echo "unknown"`

## Steps

1. **Get branch context:**

   ```bash
   current_branch=$(git branch --show-current)

   # Determine base branch (priority order):
   # 1. From existing PR (most accurate)
   # 2. From repo's default branch
   # 3. Fallback to main/master detection
   base_branch=$(gh pr view --json baseRefName -q '.baseRefName' 2>/dev/null) ||
   base_branch=$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null) ||
   base_branch=$(git rev-parse --verify main 2>/dev/null && echo main || echo master)

   # Get changed files
   changed_files=$(git diff --name-only ${base_branch}...HEAD)

   # Get full diff
   diff=$(git diff ${base_branch}...HEAD)

   # Get commit messages for context (but NOT for the description)
   commits=$(git log ${base_branch}..HEAD --oneline)
   ```

2. **Check if PR exists:**

   ```bash
   gh pr view --json number,title,body 2>/dev/null
   ```

   If no PR exists, inform the user:
   > No PR found for this branch. Create one first with `gh pr create` or `/commit-push-pr`.

3. **Analyze the FINAL state of changes:**

   Review the diff to understand:
   - What files were added/modified/deleted
   - What functionality was added or changed
   - What bugs were fixed
   - What refactoring was done

   **IMPORTANT**: Focus ONLY on what the final diff shows. Ignore:
   - Development iterations visible in commit history
   - Approaches that were tried and reverted
   - Intermediate states that no longer exist

4. **Generate PR description following this format:**

   ```markdown
   ## Summary

   [1-3 sentences describing what this PR does]

   ## Changes

   - [Bullet point for each logical change]
   - [Group related file changes together]
   - [Focus on WHAT changed, not HOW you developed it]

   ## Testing

   [How to verify these changes work - manual steps or test commands]
   ```

5. **Update the PR:**

   ```bash
   gh pr edit --body "$(cat <<'EOF'
   [generated description]
   EOF
   )"
   ```

6. **Confirm to user:**

   > Updated PR description for #[number]. View at: [PR URL]

## Rules (from pr-rules.md)

- Describe the FINAL changes against the base branch only
- Do NOT include development history (approaches tried and abandoned)
- Do NOT mention iterations or pivots during implementation
- Reviewers care about WHAT changed, not HOW you got there
- The git history captures the journey; the description captures the destination
