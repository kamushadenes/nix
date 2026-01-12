---
allowed-tools: Task
description: Create a git commit
---

## Your Task

Use the **Task tool** with `subagent_type="git-committer"` to create a commit.

In your prompt to the agent, include:

1. **Task context**: Summarize what was being worked on in this session (from conversation history, todo list, or task-master task if applicable)
2. **Mode**: "commit only" (not full PR workflow)
3. **Any specific instructions** from the user (e.g., specific files to include, message preferences)

The agent will gather its own git context (status, diff, etc.) and create the commit.

Do not use any other tools. Return the agent's summary to the user.
