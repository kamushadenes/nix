# Task Master Rules (MANDATORY)

Use task-master MCP for all task tracking.

## Rules

1. **Use task-master for**: multi-session work, dependencies, project planning
2. **Use TodoWrite for**: single-session execution steps
3. **Never**: track multi-step work only in TodoWrite

## Quick Reference (MCP Tools)

| Tool | Purpose |
|------|---------|
| `get_tasks` | List all tasks |
| `next_task` | Get highest priority unblocked task |
| `get_task` | Get specific task details |
| `set_task_status` | Update task status |
| `add_task` | Create new task |
| `add_subtask` | Add subtask to existing task |
| `update_task` | Modify task details |
| `remove_task` | Delete a task |
| `parse_prd` | Generate tasks from PRD document |
| `expand_task` | Break task into subtasks |
| `research` | Research a topic (uses OpenRouter) |
| `add_dependency` | Link task dependencies |

## Task Statuses

- `backlog` - Not yet started
- `in-progress` - Currently working
- `done` - Completed
- `blocked` - Waiting on dependency

## Priority

- `high` - Urgent/blocking
- `medium` - Standard (default)
- `low` - Backlog

## Session Workflow

1. Start: Check `next_task` for ready work
2. Claim: `set_task_status --id=X --status=in-progress`
3. Work: Complete the task
4. Done: `set_task_status --id=X --status=done`
5. Continue: `next_task` for next item

## Project Setup

For new projects:
1. Run `/task-init` to set up task-master with Claude Code provider
2. Create `.taskmaster/docs/prd.txt` with requirements
3. Use `parse_prd` to generate initial tasks
4. Or use `add_task` to create tasks manually
