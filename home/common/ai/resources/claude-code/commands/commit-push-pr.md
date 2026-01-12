---
allowed-tools: Task
description: Commit, push, and open a PR
argument-hint: [extra-instructions]
---

## Your Task

Use the **Task tool** with `subagent_type="git-committer"` for the full PR workflow.

In your prompt to the agent, include:

1. **Task context**: Summarize what was being worked on in this session (from conversation history, todo list, or task-master task if applicable)
2. **Mode**: "full PR workflow" (branch, commit, push, PR)
3. **Any specific instructions** from the user
4. **Extra instructions**: $ARGUMENTS

The agent will:

- Gather its own git context
- Create a branch if on main
- Stage and commit changes
- Push and create a PR

Do not use any other tools. Return the agent's summary (including PR URL) to the user.
