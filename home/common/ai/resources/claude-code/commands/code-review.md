---
allowed-tools: Bash(git status:*), Bash(git diff:*), mcp__pal__clink
description: Run a multi-focus code review on current changes using clink for multi-model perspectives
---

Run a multi-focus code review on current changes using clink for multi-model perspectives.

## Steps

1. Check if there are changes to review by running `git status --short`

2. If there are no changes, inform the user and stop

3. If there are changes, get the diff for review context:

```bash
diff=$(git diff HEAD)
```

4. Run focused reviews using clink (sequentially - clink is synchronous):

```python
# Security focus
security_review = mcp__pal__clink(
    prompt=f"""Review these changes focusing ONLY on security vulnerabilities:
- Injection attacks (SQL, command, template)
- Authentication/authorization issues
- Data exposure risks
- Input validation gaps

Changes:
{diff}

Output: List findings with severity (Critical/High/Medium/Low) and file:line references.""",
    cli="codex"
)

# Code quality focus
quality_review = mcp__pal__clink(
    prompt=f"""Review these changes focusing ONLY on code quality:
- Simplicity and readability
- Naming conventions
- Code duplication
- Complexity issues

Changes:
{diff}

Output: List findings with severity and file:line references.""",
    cli="codex"
)

# Error handling focus
error_review = mcp__pal__clink(
    prompt=f"""Review these changes focusing ONLY on error handling:
- Missing error checks
- Silent failures (swallowed exceptions)
- Improper exception handling
- Missing cleanup in error paths

Changes:
{diff}

Output: List findings with severity and file:line references.""",
    cli="codex"
)
```

5. Present findings organized by severity:

   - **Critical Issues** - Must fix before committing
   - **Warnings** - Should address soon
   - **Suggestions** - Nice to have improvements
   - **Positive Notes** - What's done well

6. Offer to help address any issues found
