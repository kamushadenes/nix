---
allowed-tools: Task, Bash(ls:*), Read, MCPSearch, mcp__task-master-ai__*
description: Convert a Claude Code plan file into task-master tasks for cross-session tracking
---

# Convert Plan to Task-Master Tasks

## Arguments

$ARGUMENTS (optional - path to plan file, defaults to most recent in ~/.claude/plans/)

Use the **Task tool** with `subagent_type='general-purpose'` to convert the plan.

## Agent Instructions

1. **Find the plan file**
   - If argument provided, use that path
   - Otherwise: `ls -t ~/.claude/plans/*.md | head -1`

2. **Parse the plan structure**
   - Title: First heading
   - Phases: Each `### Phase N:` section

3. **Create tasks using task-master MCP**
   - First load the MCP tool: `MCPSearch` with `select:mcp__task-master-ai__add_task`
   - Use `add_task` for each phase
   - Set appropriate priority (high for Phase 1, medium for later phases)

4. **Return summary**:
   ```
   Created from: [filename]
   Tasks: [N] created
   Run task-master `next_task` to start.
   ```
