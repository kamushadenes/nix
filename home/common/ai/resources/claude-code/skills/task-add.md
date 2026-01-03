---
name: task-add
description: Create a new task in the task management system interactively.
---

# Interactive Task Creation

This skill guides you through creating a well-structured task for the task management system.

## Usage

When invoked, interactively gather the following from the user using the AskUserQuestion tool:

1. **Title** (required) - Clear, concise description of the work
2. **Description** - Detailed context, requirements, constraints
3. **Priority** - 1 (critical), 2 (high), 3 (normal), 4 (low), 5 (backlog)
4. **Acceptance Criteria** - List of verifiable conditions for "done"
5. **Context Files** - Relevant files to include
6. **Tags** - Categories for organization

## Process

### Step 1: Gather Basic Info

Ask the user for the task title and description:

```
What task would you like to create?
- Provide a clear, concise title
- Optionally describe the requirements in detail
```

### Step 2: Determine Priority

Ask about urgency and impact:

| Priority | Use When                                    |
| -------- | ------------------------------------------- |
| 1        | Production issue, blocking others           |
| 2        | Important feature, time-sensitive           |
| 3        | Normal work, no deadline pressure (default) |
| 4        | Nice to have, can wait                      |
| 5        | Ideas, future work, low importance          |

### Step 3: Define Acceptance Criteria

Help the user create measurable, verifiable criteria:

Good criteria:
- "Login form validates email format"
- "API returns 200 for valid requests"
- "All tests pass"
- "No TypeScript errors"

Bad criteria:
- "Works correctly" (vague)
- "Good performance" (unmeasurable)

### Step 4: Identify Context Files

Based on the task description, suggest relevant files from the codebase.
Use Glob/Grep to find related files if needed.

### Step 5: Create the Task

Use the `task_create` MCP tool:

```python
result = task_create(
    title="User's title",
    description="Detailed description...",
    priority=3,
    acceptance_criteria=["Criterion 1", "Criterion 2"],
    context_files=["src/auth/login.ts", "src/types/user.ts"],
    tags=["feature", "auth"]
)
```

### Step 6: Confirm and Next Steps

Show the created task_id and suggest next actions:

- For simple tasks: `task_update(task_id, status="todo")` then work on it
- For complex tasks: `task_start_discussion(task_id)` to begin consensus building

## Example Session

User: "/task-add"

Claude: "What task would you like to create?"

User: "Add dark mode toggle to settings"

Claude: Uses AskUserQuestion for priority, criteria, etc.

Claude: Creates task with:
- Title: "Add dark mode toggle to settings"
- Priority: 3
- Acceptance criteria: ["Toggle visible in settings", "Theme persists on reload", "Respects system preference"]
- Context files: ["src/settings/page.tsx", "src/styles/theme.ts"]

Claude: "Created task task_abc123. This is a UI feature - would you like me to start a discussion phase to get design input from multiple agents?"

## Tips

- Break large tasks into subtasks using `parent_task_id`
- Use tags for filtering: "feature", "bugfix", "refactor", "docs", "test"
- Set dependencies if task requires another task to complete first
- For urgent issues, use priority 1 and skip discussion phase
