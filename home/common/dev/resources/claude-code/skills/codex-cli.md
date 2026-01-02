---
name: codex-cli
description: Run Codex CLI for code review and second opinions via PAL clink. Primary use is code review before commits/PRs. Also supports general queries for a non-Claude perspective.
---

# Codex CLI via PAL clink

Run OpenAI Codex for code review and second opinions using PAL's clink tool.

## Quick Reference

| Pattern            | Clink Call                                                    |
| ------------------ | ------------------------------------------------------------- |
| Review uncommitted | `clink with codex codereviewer to review uncommitted changes` |
| Review vs branch   | `clink with codex codereviewer to review changes vs main`     |
| Security focus     | `clink with codex codereviewer to audit for security issues`  |
| General query      | `clink with codex to [your question]`                         |

## When to Use

### Code Review (Primary)

- Before creating a commit
- Before opening a PR
- Reviewing specific commits
- Security-focused review

### Plan Review

- Review implementation plans before executing
- Get a second opinion on architectural decisions
- Validate approach before significant changes

### Second Opinion (Secondary)

- Want a non-Claude perspective
- Quick implementation validation
- Alternative approach suggestions

## When NOT to Use

- Complex architectural analysis (use claude-cli instead)
- When you need detailed reasoning chains
- File modifications (clink runs in isolated context)

## Code Review Workflow (Recommended)

Use PAL's clink tool to spawn a Codex subagent:

```python
result = mcp__pal__clink(
    prompt="Review uncommitted changes for bugs, security issues, and code quality",
    cli_name="codex",
    role="codereviewer"
)
```

Benefits:

- Single tool call
- Isolated context (doesn't pollute main conversation)
- Returns only final results
- Role-specific system prompts for better reviews

### With file context

```python
result = mcp__pal__clink(
    prompt="Review this authentication module for security vulnerabilities",
    cli_name="codex",
    role="codereviewer",
    files=["src/auth/login.py", "src/auth/session.py"]
)
```

### Custom focus

```python
result = mcp__pal__clink(
    prompt="Focus on error handling and edge cases in the payment flow",
    cli_name="codex",
    role="codereviewer"
)
```

## Available Roles

| Role           | Use Case                                    |
| -------------- | ------------------------------------------- |
| `default`      | General questions, quick answers            |
| `codereviewer` | Code analysis with severity classifications |
| `planner`      | Multi-phase strategic planning              |

## Parallel Multi-Focus Reviews

Run multiple codex agents in parallel with different focuses.
Launch all in a single message with multiple tool calls:

```python
# Security focus
security = mcp__pal__clink(
    prompt="Focus exclusively on security vulnerabilities in uncommitted changes",
    cli_name="codex",
    role="codereviewer"
)

# Simplicity focus (in parallel)
simplicity = mcp__pal__clink(
    prompt="Focus on code simplicity and readability in uncommitted changes",
    cli_name="codex",
    role="codereviewer"
)

# Performance focus (in parallel)
performance = mcp__pal__clink(
    prompt="Focus on performance issues in uncommitted changes",
    cli_name="codex",
    role="codereviewer"
)
```

**Suggested review focuses:**

- Security vulnerabilities
- Code simplicity/readability
- Performance issues
- Error handling
- Test coverage gaps
- Best practices violations

## Second Opinion (General Queries)

For general questions beyond code review:

```python
result = mcp__pal__clink(
    prompt="Is this caching approach reasonable? [describe approach]",
    cli_name="codex",
    role="default"
)
```

## Conversation Continuity

Resume a previous clink conversation:

```python
result = mcp__pal__clink(
    prompt="Now focus on the edge cases we discussed",
    cli_name="codex",
    continuation_id="previous_conversation_id"
)
```

## Error Handling

| Error          | Action                                |
| -------------- | ------------------------------------- |
| CLI not found  | Ensure codex is installed and in PATH |
| Auth errors    | Run `codex auth` to authenticate      |
| Rate limits    | Wait 30s and retry once               |
| Empty response | Check PAL server logs for issues      |

## Tips

1. **Use codereviewer role**: Better structured output for reviews
2. **Pass file paths**: Use `files` parameter for context without token bloat
3. **Parallel reviews**: Run multiple focused reviews simultaneously
4. **Isolated context**: Each clink call gets fresh context
5. **Chain with other PAL tools**: Use planner → clink → codereview workflows
