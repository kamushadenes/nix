Run a multi-focus code review on current changes using the orchestrator system.

## Steps

1. Check if there are changes to review by running `git status --short`

2. If there are no changes, inform the user and stop

3. If there are changes, create a review task and spawn parallel agents:

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

# Launch 3 parallel Codex reviews with different focuses
# All run in read-only mode automatically

# Security focus
security = mcp__orchestrator__ai_spawn(
    prompt="Review uncommitted changes focusing ONLY on security vulnerabilities: injection attacks, auth issues, data exposure, input validation. Use task_comment to record findings.",
    cli="codex",
    task_id=task_id
)

# Code quality focus (in parallel)
quality = mcp__orchestrator__ai_spawn(
    prompt="Review uncommitted changes focusing ONLY on code quality: simplicity, readability, naming, duplication, complexity. Use task_comment to record findings.",
    cli="codex",
    task_id=task_id
)

# Error handling focus (in parallel)
errors = mcp__orchestrator__ai_spawn(
    prompt="Review uncommitted changes focusing ONLY on error handling: missing error checks, silent failures, improper exception handling. Use task_comment to record findings.",
    cli="codex",
    task_id=task_id
)
```

4. Wait for all reviews to complete using `ai_fetch` for each job

5. Retrieve and aggregate comments from the task:

```python
comments = mcp__orchestrator__task_comments(task_id)
```

6. Present findings organized by severity:

   - **Critical Issues** - Must fix before committing
   - **Warnings** - Should address soon
   - **Suggestions** - Nice to have improvements
   - **Positive Notes** - What's done well

7. Mark the review task as complete:

```python
mcp__orchestrator__task_complete(
    task_id=task_id,
    result="Code review completed with findings aggregated"
)
```

8. Offer to help address any issues found
