---
description:
  Quick code review of uncommitted changes using 3 parallel reviewer subagents
---

Run a focused code review on current uncommitted changes using 3 parallel
reviewer subagents.

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

3. **Spawn 3 parallel reviewer subagents:**

   | Subagent              | Focus                                                              |
   | --------------------- | ------------------------------------------------------------------ |
   | security-auditor      | Injection attacks, auth issues, data exposure, input validation    |
   | code-reviewer         | Simplicity, readability, naming, duplication, complexity           |
   | silent-failure-hunter | Missing error checks, swallowed exceptions, cleanup in error paths |

   Each subagent receives the review context (diff, changed files) and their
   domain focus. Use `task()` to spawn all 3 in parallel, then aggregate results
   when all complete.

4. **Present findings by severity:**
   - **Critical Issues** - Must fix before committing
   - **Warnings** - Should address soon
   - **Suggestions** - Nice to have improvements
   - **Positive Notes** - What's done well

5. **Offer to help address any issues found**
