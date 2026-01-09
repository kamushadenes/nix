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

**Use when:** Complex bugs, major architecture decisions, security-critical code
**Skip when:** Simple tasks, confident approach, minor refactoring

Default: Make own decisions. Escalate only when complexity warrants it.

## Multi-Model Sub-Agents

`consensus`, `debugger`, `planner`, `precommit`, `thinkdeep`, `tracer`

Use `code-reviewer` directly for most reviews, not multi-model consensus.

## Subagent User Input

Subagents cannot use AskUserQuestion. When subagent returns options (A/B/C lists, "Choose:", etc.), **you must** relay via AskUserQuestion, then pass selection back.
