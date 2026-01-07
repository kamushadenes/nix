---
allowed-tools: Bash(git status:*), Bash(git diff:*), mcp__orchestrator__ai_spawn, mcp__orchestrator__ai_fetch
description: Run a multi-focus code review on current changes using parallel AI models
---

Run a multi-focus code review on current changes using parallel AI models for diverse perspectives.

## Steps

1. Check if there are changes to review by running `git status --short`

2. If there are no changes, inform the user and stop

3. If there are changes, get the diff for review context:

```bash
diff=$(git diff HEAD)
```

4. Spawn focused reviews in parallel using ai_spawn:

```python
# Security focus
security_job = mcp__orchestrator__ai_spawn(
    cli="codex",
    prompt=f"""Review these changes focusing ONLY on security vulnerabilities:
- Injection attacks (SQL, command, template)
- Authentication/authorization issues
- Data exposure risks
- Input validation gaps

Changes:
{diff}

Output: List findings with severity (Critical/High/Medium/Low) and file:line references."""
)

# Code quality focus
quality_job = mcp__orchestrator__ai_spawn(
    cli="codex",
    prompt=f"""Review these changes focusing ONLY on code quality:
- Simplicity and readability
- Naming conventions
- Code duplication
- Complexity issues

Changes:
{diff}

Output: List findings with severity and file:line references."""
)

# Error handling focus
error_job = mcp__orchestrator__ai_spawn(
    cli="codex",
    prompt=f"""Review these changes focusing ONLY on error handling:
- Missing error checks
- Silent failures (swallowed exceptions)
- Improper exception handling
- Missing cleanup in error paths

Changes:
{diff}

Output: List findings with severity and file:line references."""
)
```

5. Fetch all results (they ran in parallel):

```python
security_review = mcp__orchestrator__ai_fetch(job_id=security_job.job_id, timeout=120)
quality_review = mcp__orchestrator__ai_fetch(job_id=quality_job.job_id, timeout=120)
error_review = mcp__orchestrator__ai_fetch(job_id=error_job.job_id, timeout=120)
```

6. Present findings organized by severity:

   - **Critical Issues** - Must fix before committing
   - **Warnings** - Should address soon
   - **Suggestions** - Nice to have improvements
   - **Positive Notes** - What's done well

7. Offer to help address any issues found
