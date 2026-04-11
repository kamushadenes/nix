---
name: commit-push-pr
description: Commit, push, and open a PR. Use when the user asks to create a pull request, open a PR, or push and create PR.
---

# Commit, Push, and PR Workflow

Delegate to the git-committer agent for the full PR workflow.

## Task for git-committer agent

### Phase 1: Commit

1. Gather git context:
   - Run `git status --short` to see changed files
   - Run `git diff --staged` and `git diff` for changes
   - Run `git log --oneline -5` for commit style

2. Stage and commit changes with an appropriate message.

### Phase 2: Push

3. Determine the remote branch:
   ```bash
   git rev-parse --abbrev-ref HEAD
   git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "no upstream"
   ```

4. Push to remote:
   ```bash
   git push -u origin HEAD
   ```

### Phase 3: Create PR

5. Determine the base branch:
   ```bash
   git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
   ```

6. Get the diff against base for PR description:
   ```bash
   git log --oneline $(git merge-base HEAD origin/main)..HEAD
   git diff origin/main...HEAD --stat
   ```

7. Create the PR:
   ```bash
   gh pr create --title "<title>" --body "<body with ## Summary and ## Test plan>"
   ```

### Phase 4: Verify

8. Watch PR checks:
   ```bash
   gh pr checks --watch
   ```

9. Check mergeable status:
   ```bash
   gh pr view --json mergeable,mergeStateStatus
   ```

10. If there are merge conflicts, attempt to resolve them:
    ```bash
    git fetch origin main
    git merge origin/main --no-edit
    # resolve conflicts if any
    git push
    ```

11. Return the PR URL and check status.

Include the user's additional instructions when delegating the task.
