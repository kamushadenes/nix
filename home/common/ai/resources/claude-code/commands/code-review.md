---
allowed-tools: Bash(git status:*), Bash(git diff:*), mcp__orchestrator__task_create, mcp__pal__clink, mcp__orchestrator__task_comment, mcp__orchestrator__task_comments, mcp__orchestrator__task_complete
description: Run a multi-focus code review on current changes using the orchestrator system
---

Run a multi-focus code review on current changes using clink for multi-model perspectives.

## Steps

1. Check if there are changes to review by running `git status --short`

2. If there are no changes, inform the user and stop

3. If there are changes, create a review task:

```python
import json

# Create a code review task
task_result = mcp__orchestrator__task_create(
    title="Code review for uncommitted changes",
    description="Multi-focus code review covering security, quality, and error handling",
    priority=2,
    acceptance_criteria='["Security vulnerabilities identified", "Code quality issues flagged", "Error handling gaps found"]',
    created_by="user"
)
task_id = json.loads(task_result)["task_id"]
```

4. Get the diff for review context:

```python
diff = Bash("git diff HEAD")
```

5. Run focused reviews using clink (sequentially - clink is synchronous):

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

# Record security findings
mcp__orchestrator__task_comment(task_id, security_review, comment_type="note", agent_type="codex")

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

mcp__orchestrator__task_comment(task_id, quality_review, comment_type="note", agent_type="codex")

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

mcp__orchestrator__task_comment(task_id, error_review, comment_type="note", agent_type="codex")
```

6. Retrieve and aggregate comments from the task:

```python
comments = mcp__orchestrator__task_comments(task_id)
```

7. Present findings organized by severity:

   - **Critical Issues** - Must fix before committing
   - **Warnings** - Should address soon
   - **Suggestions** - Nice to have improvements
   - **Positive Notes** - What's done well

8. Mark the review task as complete:

```python
mcp__orchestrator__task_complete(
    task_id=task_id,
    result="Code review completed with findings aggregated"
)
```

9. Offer to help address any issues found
