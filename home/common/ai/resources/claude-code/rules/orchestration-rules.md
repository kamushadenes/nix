# AI Orchestration Rules

## Agent Teams (Parallel Task Execution)
- Use `/delegate-tasks` to spawn an Agent Team for parallel work
- Lead coordinates, teammates execute independently in worktrees
- TeammateIdle/TaskCompleted hooks enforce quality gates

## Subagents (Focused Analysis)
- Use Task tool for quick focused work within a session
- Review agents, debugger, planner etc. are subagents
- Better than Teams when only the result matters

## When to Use Teams vs Subagents
**Teams**: 2+ independent tasks, each needing full Claude session, tasks benefit from discussion
**Subagents**: Focused analysis, quick results, no inter-agent coordination needed

## Subagent User Input

Subagents cannot use AskUserQuestion. Relay via AskUserQuestion, then pass back.

## Issue Resolution Workflow

1. Create worktree: `wt switch -c feat/<issue>-<desc>`
2. Work in isolation
3. Complete with PR
