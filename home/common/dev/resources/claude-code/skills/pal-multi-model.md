---
name: pal-multi-model
description: Multi-model AI collaboration via PAL MCP. Use when seeking second opinions, debugging complex issues, building consensus on architectural decisions, conducting code reviews, or needing external validation on analysis.
---

# PAL Multi-Model AI

Consult external AI models for second opinions, debugging, consensus building, and expert validation. PAL provides access to multiple models (GPT, Gemini, Claude via OpenRouter, etc.) for collaborative problem-solving.

## Quick Reference

| Tool                   | Purpose                                            |
| ---------------------- | -------------------------------------------------- |
| `mcp__pal__chat`       | General discussion, brainstorming, quick questions |
| `mcp__pal__thinkdeep`  | Complex problem analysis with hypothesis testing   |
| `mcp__pal__consensus`  | Multi-model debate for decisions                   |
| `mcp__pal__codereview` | Systematic code review with expert validation      |
| `mcp__pal__debug`      | Root cause analysis with external validation       |
| `mcp__pal__analyze`    | Codebase analysis (architecture, performance)      |
| `mcp__pal__refactor`   | Code smell detection, modernization planning       |
| `mcp__pal__testgen`    | Test suite generation with edge cases              |
| `mcp__pal__secaudit`   | Security vulnerability assessment                  |
| `mcp__pal__precommit`  | Git change validation before committing            |
| `mcp__pal__planner`    | Complex project planning with branching            |
| `mcp__pal__docgen`     | Documentation generation                           |
| `mcp__pal__apilookup`  | Current API/SDK documentation lookup               |
| `mcp__pal__challenge`  | Critical analysis to prevent reflexive agreement   |
| `mcp__pal__clink`      | Bridge to external CLIs (gemini, codex, claude)    |
| `mcp__pal__listmodels` | Show available models                              |

**Note:** Some tools are disabled by default (analyze, refactor, testgen, secaudit, docgen). Check server config if needed.

## When to Use External Models

**Do use PAL when:**

- Stuck on a complex bug after initial investigation
- Making architectural decisions with tradeoffs
- Need validation before major refactoring
- Security-sensitive code needs audit
- Want diverse perspectives on approach

**Don't use PAL when:**

- Simple, straightforward tasks
- Already confident in approach
- Just need to execute known solution

## Key Concepts

### Model Selection

- Default: auto-selection based on task
- **Best models**: `google/gemini-3-pro-preview` and `openai/gpt-5.2-pro`
- Use `listmodels` to see all available options

### Continuation ID

Reuse `continuation_id` across calls to maintain conversation context:

```
# First call returns a continuation_id
result1 = mcp__pal__debug(step="Investigating...", continuation_id=None, ...)

# Subsequent calls reuse it
result2 = mcp__pal__debug(step="Found evidence...", continuation_id="abc123", ...)
```

### Confidence Levels

For investigation tools (debug, thinkdeep, analyze):

- `exploring` → just starting
- `low/medium/high` → building evidence
- `very_high/almost_certain` → strong confidence
- `certain` → 100% confident, skips external validation

## Common Workflows

### Get a Second Opinion

```
mcp__pal__chat(
    prompt="I'm considering using Redis for session storage vs PostgreSQL. What are the tradeoffs?",
    model="auto",
    working_directory_absolute_path="/path/to/project"
)
```

### Debug Complex Issue

```
mcp__pal__debug(
    step="Investigating why requests timeout after 30s under load",
    step_number=1,
    total_steps=3,
    next_step_required=True,
    findings="Found connection pool exhaustion in logs",
    relevant_files=["/path/to/db.py", "/path/to/config.py"],
    model="auto"
)
```

### Build Consensus on Architecture

```
mcp__pal__consensus(
    step="Evaluate: Should we use microservices or monolith for this MVP?",
    step_number=1,
    total_steps=4,
    next_step_required=True,
    findings="Initial analysis of requirements",
    models=[
        {"model": "google/gemini-2.5-pro", "stance": "for"},
        {"model": "openai/gpt-5", "stance": "against"}
    ]
)
```

### Code Review Before PR

```
mcp__pal__codereview(
    step="Reviewing authentication changes for security and best practices",
    step_number=1,
    total_steps=2,
    next_step_required=True,
    findings="Examining JWT implementation",
    relevant_files=["/path/to/auth.py"],
    review_type="security",
    model="auto"
)
```

## Tips

- **Be specific**: Include file paths, error messages, and context
- **Use relevant_files**: Always provide absolute paths to code being discussed
- **Step through investigations**: Use step_number/total_steps for complex analyses
- **Reuse continuation_id**: Maintains context across multiple calls
- **Match tool to task**: Use `debug` for bugs, `analyze` for architecture, `consensus` for decisions
- **Best for critical thinking**: `google/gemini-3-pro-preview` and `openai/gpt-5.2-pro`
- **Context revival**: If context resets, other models can remind each other of previous discussions
