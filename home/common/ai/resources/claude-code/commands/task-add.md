Create a new task in the task management system interactively.

## Steps

1. Ask the user for task details using AskUserQuestion:

   - **Title**: A concise title for the task (required)
   - **Priority**: 1 (critical) to 5 (low), default 2
   - **Description**: Detailed description of what needs to be done

2. Ask about acceptance criteria:

   - What conditions must be met for this task to be considered complete?
   - List each criterion separately

3. Ask about context (optional):

   - Which files are relevant to this task?
   - Are there any dependencies on other tasks?
   - Any tags to categorize this task?

4. Create the task using the orchestrator MCP:

```python
result = mcp__orchestrator__task_create(
    title=title,
    description=description,
    priority=priority,
    tags=tags,  # JSON array string e.g., '["feature", "auth"]'
    acceptance_criteria=criteria,  # JSON array string
    context_files=files,  # JSON array string
    dependencies=deps,  # JSON array string
    created_by="user"
)
```

5. Present the created task to the user with its ID

6. Ask if the user wants to:
   - Start the discussion phase immediately (`task_start_discussion`)
   - Move directly to development (`task_start_dev`)
   - Leave it in backlog for later

## Task Workflow Reference

Tasks follow this lifecycle:

```
backlog -> todo -> discussing -> in_progress -> review -> qa -> done
                       |              |           |       |
                    stalled        blocked     failed   rejected
```

### Discussion Phase (Recommended for Complex Tasks)

The discussion phase spawns 3 agents (Claude, Codex, Gemini) to:

- Analyze requirements
- Propose implementation approaches
- Identify potential issues
- Reach consensus before development begins

All 3 agents must vote "ready" to proceed to development.

### Development Phase

Claude agent implements the task with full access to the codebase.

### Review Phase

Codex reviews code changes in read-only mode.

### QA Phase

3 agents (Claude, Codex, Gemini) verify acceptance criteria in parallel.
Majority (2/3) approval moves task to "done".
