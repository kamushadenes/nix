---
allowed-tools: Task, Bash(gh pr:*)
description: Commit, push, and open a PR
argument-hint: [extra-instructions]
---

## Your Task

Use the **Task tool** with `subagent_type="git-committer"` for the full PR workflow.

In your prompt to the agent, include:

1. **Task context**: Summarize what was being worked on in this session (from conversation history or todo list)
2. **Mode**: "full PR workflow" (branch, commit, push, PR)
3. **Any specific instructions** from the user
4. **Extra instructions**: $ARGUMENTS

The agent will:

- Gather its own git context
- Create a branch if on main
- Stage and commit changes
- Push and create a PR

## After PR Creation

Once the PR is created, follow the **pr-completion** skill workflow:

1. Run `gh pr checks --watch` to wait for CI checks to complete
2. If checks fail, fix issues, push, and re-run checks
3. Run `gh pr view --json mergeable` to verify no conflicts
4. If conflicts exist, resolve them with `gh pr update-branch` or rebase

Return the agent's summary (including PR URL) and the final check/mergeable status to the user.
