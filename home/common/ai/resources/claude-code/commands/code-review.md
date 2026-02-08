---
allowed-tools: Bash(git status:*), Bash(git diff:*), Task
description: Quick code review of uncommitted changes using 3 reviewer teammates
---

Run a focused code review on current uncommitted changes using an Agent Team of 3 reviewers.

## Steps

1. **Check for changes:**
   ```bash
   git status --short
   ```
   If no changes, inform user and stop.

2. **Get the diff:**
   ```bash
   diff=$(git diff HEAD)
   changed_files=$(git diff --name-only HEAD)
   ```

3. **Create a review team with 3 focused reviewer teammates:**

   | Teammate | Agent | Focus |
   |----------|-------|-------|
   | 1 | security-auditor | Injection attacks, auth issues, data exposure, input validation |
   | 2 | code-reviewer | Simplicity, readability, naming, duplication, complexity |
   | 3 | silent-failure-hunter | Missing error checks, swallowed exceptions, cleanup in error paths |

   Each teammate gets the review context (diff, changed files) and their domain focus. Reviewers can discuss and cross-reference findings.

4. **Present findings by severity:**

   - **Critical Issues** - Must fix before committing
   - **Warnings** - Should address soon
   - **Suggestions** - Nice to have improvements
   - **Positive Notes** - What's done well

5. **Offer to help address any issues found**
