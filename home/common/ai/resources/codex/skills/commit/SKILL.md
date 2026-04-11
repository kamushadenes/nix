---
name: commit
description: Create a git commit. Use when the user asks to commit changes, save work, or create a commit.
---

# Commit Workflow

Delegate to the git-committer agent with the following task:

## Task for git-committer agent

1. Gather git context:
   - Run `git status --short` to see changed files
   - Run `git diff --staged` to see staged changes
   - Run `git diff` to see unstaged changes
   - Run `git log --oneline -5` to see recent commit message style

2. If nothing is staged, stage all modified/new files relevant to the current work.

3. Analyze all staged changes and draft a commit message:
   - Use conventional commit format if the repo follows it
   - Summarize the nature of the changes (feat, fix, refactor, docs, test, etc.)
   - Keep the first line under 72 characters
   - Add a body if the changes need explanation
   - Never commit files that likely contain secrets (.env, credentials, tokens)

4. Create the commit using:
   ```bash
   git commit -m "<message>"
   ```

5. Run `git status` after to verify success.

6. Return a summary of what was committed (files changed, commit hash, message).

Include the user's additional instructions when delegating the task.
