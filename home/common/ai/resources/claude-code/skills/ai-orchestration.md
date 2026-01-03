---
name: ai-orchestration
description: Multi-model AI collaboration via orchestrator MCP. Use when seeking second opinions, debugging complex issues, building consensus on architectural decisions, conducting code reviews, or needing external validation on analysis.
---

# AI CLI Orchestration

Query external AI models (claude, codex, gemini) for second opinions, debugging, consensus building, and expert validation. Use the PAL MCP's `clink` tool to bridge to external AI CLIs.

## Role Hierarchy

Claude Code is the **orchestrator**. When calling external AI agents:

| CLI    | Role        | Mode      | Capabilities                       |
| ------ | ----------- | --------- | ---------------------------------- |
| claude | Worker/Peer | Full      | Can execute any tool/command       |
| codex  | Reviewer    | Read-only | Code review, analysis, suggestions |
| gemini | Researcher  | Read-only | Web search, documentation lookup   |

## Quick Reference

| Tool    | Purpose                                          |
| ------- | ------------------------------------------------ |
| `clink` | Query external AI CLI (claude, codex, or gemini) |

The `clink` tool is synchronous - it runs the CLI and returns the result.

## When to Use External Models

**Do use when:**

- Stuck on a complex bug after initial investigation
- Making architectural decisions with tradeoffs
- Need validation before major refactoring
- Security-sensitive code needs audit
- Want diverse perspectives on approach

**Don't use when:**

- Simple, straightforward work
- Already confident in approach
- Just need to execute known solution

## Sub-Agent Delegation

For complex workflows, delegate to specialized sub-agents instead of running clink directly. This keeps the orchestrator focused and leverages specialized expertise.

### Available Sub-Agents

| Sub-Agent               | Use Case                        |
| ----------------------- | ------------------------------- |
| `code-reviewer`         | Code quality review             |
| `security-auditor`      | Security vulnerability analysis |
| `test-analyzer`         | Test coverage and quality       |
| `documentation-writer`  | Documentation quality review    |
| `silent-failure-hunter` | Detects swallowed errors        |
| `performance-analyzer`  | Performance issue detection     |
| `type-checker`          | Type safety analysis            |
| `refactoring-advisor`   | Refactoring opportunities       |
| `code-simplifier`       | Code complexity reduction       |
| `comment-analyzer`      | Code comment quality            |
| `dependency-checker`    | Dependency health and security  |
| `consensus`             | Multi-model perspective         |
| `debugger`              | Root cause investigation        |
| `planner`               | Project planning                |
| `precommit`             | Pre-commit validation           |
| `thinkdeep`             | Extended thinking/analysis      |
| `tracer`                | Execution flow analysis         |

### When to Delegate vs Direct clink

**Delegate to sub-agent:**

- Complex analysis needing specialized focus
- When you want structured findings with confidence scores

**Use direct clink:**

- Quick questions needing external perspective
- Simple consensus building
- Web search or documentation lookup

## Basic Workflows

### Quick Question

```python
# Ask a single model
result = clink(
    prompt="What's the best way to handle rate limiting in Python?",
    cli="claude"  # or "codex" or "gemini"
)
```

### Second Opinion (Sequential)

```python
# Query multiple models sequentially
claude_opinion = clink(prompt="Should I use Redis or PostgreSQL?", cli="claude")
codex_opinion = clink(prompt="Should I use Redis or PostgreSQL?", cli="codex")
gemini_opinion = clink(prompt="Should I use Redis or PostgreSQL?", cli="gemini")

# Synthesize results
```

**Note:** clink is synchronous. For true parallelism, use Claude Code sub-agents
(they run as separate processes).

### Code Review

```python
# Get external review perspective
result = clink(
    prompt="Review these changes for security issues. Focus on auth code.",
    cli="codex",
    files=["src/auth/"]
)
```

## clink Parameters

| Parameter | Type | Default  | Description                         |
| --------- | ---- | -------- | ----------------------------------- |
| prompt    | str  | required | The question/task                   |
| cli       | str  | "claude" | "claude", "codex", or "gemini"      |
| files     | list | []       | Files to include as context         |
| role      | str  | ""       | Optional role preset (see PAL docs) |

## Multi-Model Patterns

### Consensus Building

Query the same question to all models, compare responses:

```python
# Query all 3 models
claude_view = clink(prompt="Should we use microservices?", cli="claude")
codex_view = clink(prompt="Should we use microservices?", cli="codex")
gemini_view = clink(prompt="Should we use microservices?", cli="gemini")

# Synthesize: look for agreement, note disagreements
```

### Security Audit

Run security-focused reviews from multiple perspectives:

```python
security_prompt = """
Review src/auth/ for security vulnerabilities.
Focus on: injection, auth bypass, data exposure.
Output: List findings with severity and file:line references.
"""

codex_audit = clink(prompt=security_prompt, cli="codex", files=["src/auth/"])
claude_audit = clink(prompt=security_prompt, cli="claude", files=["src/auth/"])

# Aggregate findings, deduplicate
```

## Writing Good Prompts for External Models

When using clink, include:

1. **Clear task description** - what exactly to do
2. **Expected output format** - how to structure the response
3. **Scope boundaries** - what files/areas to focus on
4. **Read-only reminder** (for codex/gemini) - they cannot modify anything

### Good Prompt Example

```text
Review the authentication module for security vulnerabilities.

Focus on: src/auth/*.py
Output: List of findings with severity (high/medium/low) and line numbers
Constraints: This is a read-only review - identify issues only, do not suggest code changes
```

### Bad Prompt Example

```text
Look at the code and tell me what you think
```

## Tips

- **Be specific**: Include file paths, error messages, and context
- **Use appropriate CLI**: codex for code review, gemini for web search
- **Delegate complex work**: Use sub-agents for structured analysis
- **Remember read-only**: Codex and Gemini cannot execute commands or modify files
- **Include files**: Use the `files` parameter to provide code context
