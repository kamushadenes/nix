# AI Orchestration Rules

## Role Hierarchy

| CLI    | Role       | Mode      | Use For                   |
| ------ | ---------- | --------- | ------------------------- |
| claude | Worker     | Full      | Any tool/command          |
| codex  | Reviewer   | Read-only | Code review, analysis     |
| gemini | Researcher | Read-only | Web search, docs lookup   |

## Constraints

- **codex/gemini**: Read-only, no file modifications
- **claude workers**: Full access, use sparingly for parallel work
- External agent prompts must include: task, output format, scope, read-only reminder

## When to Use Multi-Model

**Multi-model orchestration has latency cost.** Use parallel execution to minimize wait time.

**Use when:**
- Stuck on complex bugs after initial investigation
- Major architectural decisions with significant tradeoffs
- Security-critical code needing multiple perspectives
- Debugging issues that resist initial analysis

**Don't use when:**
- Simple, straightforward tasks (most work)
- Already confident in approach
- Just need to execute known solution
- Minor refactoring or code cleanup
- Single-file changes with clear scope

Default: Make own decisions. Escalate only when complexity warrants it.

## Multi-Model Sub-Agents

`consensus`, `debugger`, `planner`, `precommit`, `thinkdeep`, `tracer`

Use `code-reviewer` directly for most reviews, not multi-model consensus.

## Subagent User Input

Subagents cannot use AskUserQuestion. When subagent returns options (A/B/C lists, "Choose:", etc.), **you must** relay via AskUserQuestion, then pass selection back.
