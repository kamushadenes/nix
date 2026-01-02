---
name: claude-cli
description: Run another Claude CLI instance via PAL clink for parallel analysis, deep investigation, or when current context is saturated. Use when you need to offload complex analysis while continuing other work.
---

# Claude CLI via PAL clink

Run a separate Claude instance for parallel analysis and investigation using PAL's clink tool.

## Quick Reference

| Pattern        | Clink Call                                             |
| -------------- | ------------------------------------------------------ |
| Deep analysis  | `clink with claude planner to analyze architecture`    |
| Research       | `clink with claude to research [topic]`                |
| Second opinion | `clink with claude to review this approach: [details]` |

## When to Use

### Deep Analysis (Primary)

- Complex architectural investigation needing fresh context
- Multi-file analysis requiring dedicated attention
- When current context is too saturated
- Research tasks while main instance continues work

### Plan Review

- Review implementation plans before executing
- Get a second opinion on architectural decisions
- Validate complex approaches before significant changes

### Parallel Processing

- Offload analysis while continuing other work
- Run multiple investigations simultaneously
- Background research without blocking main work

## When NOT to Use

- Simple questions you can answer directly
- Code review (use codex-cli with codereviewer role instead)
- Quick sanity checks

## Recommended Workflow (PAL clink)

Use PAL's clink tool to spawn a Claude subagent:

```python
result = mcp__pal__clink(
    prompt="Analyze the architecture of this codebase focusing on service boundaries and data flow",
    cli_name="claude",
    role="planner"
)
```

Benefits:

- Single tool call
- Isolated context (doesn't pollute main conversation)
- Returns only final results
- Role-specific system prompts

### With file context

```python
result = mcp__pal__clink(
    prompt="Analyze these modules for potential refactoring opportunities",
    cli_name="claude",
    role="planner",
    files=["src/services/auth.py", "src/services/user.py"]
)
```

## Available Roles

| Role      | Use Case                         |
| --------- | -------------------------------- |
| `default` | General questions, quick answers |
| `planner` | Multi-phase strategic planning   |

## Parallel Analysis

Run multiple Claude instances in parallel for different aspects:

```python
# Architecture analysis
arch = mcp__pal__clink(
    prompt="Analyze service boundaries and data flow patterns",
    cli_name="claude",
    role="planner"
)

# Security analysis (in parallel)
security = mcp__pal__clink(
    prompt="Review for security vulnerabilities and attack vectors",
    cli_name="claude",
    role="default"
)

# Performance analysis (in parallel)
perf = mcp__pal__clink(
    prompt="Identify performance bottlenecks and optimization opportunities",
    cli_name="claude",
    role="default"
)
```

## Conversation Continuity

Resume a previous clink conversation:

```python
result = mcp__pal__clink(
    prompt="Continue with the implementation details we discussed",
    cli_name="claude",
    continuation_id="previous_conversation_id"
)
```

## Error Handling

| Error          | Action                                 |
| -------------- | -------------------------------------- |
| CLI not found  | Ensure claude is installed and in PATH |
| Auth errors    | Run `claude login` to authenticate     |
| Rate limits    | Wait 30s and retry once                |
| Empty response | Check PAL server logs for issues       |

## Tips

1. **Use planner role**: Better structured output for complex analysis
2. **Pass file paths**: Use `files` parameter for context without token bloat
3. **Parallel work**: Run multiple analyses while continuing main work
4. **Isolated context**: Each clink call gets fresh context
5. **Chain with other PAL tools**: Use planner → clink → codereview workflows
