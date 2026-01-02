Run a multi-focus code review on current changes using Codex via PAL clink.

## Steps

1. Check if there are changes to review by running `git status --short`

2. If there are no changes, inform the user and stop

3. If there are changes, launch multiple parallel Codex reviews with different focuses:

```python
# Security focus
security = mcp__pal__clink(
    prompt="Review uncommitted changes focusing ONLY on security vulnerabilities: injection attacks, auth issues, data exposure, input validation",
    cli_name="codex",
    role="codereviewer"
)

# Code quality focus (in parallel)
quality = mcp__pal__clink(
    prompt="Review uncommitted changes focusing ONLY on code quality: simplicity, readability, naming, duplication, complexity",
    cli_name="codex",
    role="codereviewer"
)

# Error handling focus (in parallel)
errors = mcp__pal__clink(
    prompt="Review uncommitted changes focusing ONLY on error handling: missing error checks, silent failures, improper exception handling",
    cli_name="codex",
    role="codereviewer"
)
```

4. Aggregate and present findings organized by severity:

   - **Critical Issues** - Must fix before committing
   - **Warnings** - Should address soon
   - **Suggestions** - Nice to have improvements
   - **Positive Notes** - What's done well

5. Offer to help address any issues found
