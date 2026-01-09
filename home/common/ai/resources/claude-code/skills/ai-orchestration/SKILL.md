---
name: ai-orchestration
description: Multi-model AI collaboration via orchestrator MCP. Use when seeking second opinions, debugging complex issues, building consensus on architectural decisions, conducting code reviews, or needing external validation on analysis.
triggers: second opinion, multi-model, consensus, external AI, codex, gemini, model comparison, AI collaboration, expert validation, parallel AI, ai_spawn, ai_fetch
---

# AI CLI Orchestration

Query external AI models (claude, codex, gemini) for second opinions, debugging, consensus building, and expert validation.

## Tools Overview

| Tool        | Mode        | Description                                  |
| ----------- | ----------- | -------------------------------------------- |
| `ai_call`   | Synchronous | Call AI and wait for result                  |
| `ai_spawn`  | Async       | Start AI in background, get job ID           |
| `ai_fetch`  | Async       | Get result from spawned AI (with timeout)    |
| `ai_list`   | Utility     | List all running/completed AI jobs           |
| `ai_review` | Convenience | Spawn all 3 AIs in parallel with same prompt |

## Role Hierarchy

Claude Code is the **orchestrator**. When calling external AI agents:

| CLI    | Role        | Mode      | Capabilities                       |
| ------ | ----------- | --------- | ---------------------------------- |
| claude | Worker/Peer | Full      | Can execute any tool/command       |
| codex  | Reviewer    | Read-only | Code review, analysis, suggestions |
| gemini | Researcher  | Read-only | Web search, documentation lookup   |

## Parallel vs Sequential Execution

### Parallel (Recommended for Multi-Model)

Use `ai_spawn` + `ai_fetch` to run multiple models simultaneously:

```python
# Spawn all 3 models in parallel
claude_job = ai_spawn(cli="claude", prompt="Analyze this code for bugs...")
codex_job = ai_spawn(cli="codex", prompt="Review this code for patterns...")
gemini_job = ai_spawn(cli="gemini", prompt="Research best practices for...")

# All running simultaneously! Fetch results:
claude_result = ai_fetch(job_id=claude_job.job_id, timeout=120)
codex_result = ai_fetch(job_id=codex_job.job_id, timeout=120)
gemini_result = ai_fetch(job_id=gemini_job.job_id, timeout=120)

# Total time = slowest model (~60s) instead of sum (~180s)
```

Or use `ai_review` for convenience:

```python
# One call spawns all 3
review = ai_review(prompt="Analyze this architecture decision...", files=["src/"])
# Returns: AIReviewResult with jobs for claude, codex, and gemini

# Fetch each result
claude_result = ai_fetch(job_id=review.jobs["claude"].job_id, timeout=120)
```

### Sequential (When Needed)

Use `ai_call` when prompts depend on previous results:

```python
# First, get architecture analysis
arch = ai_call(cli="claude", prompt="Design the auth architecture...")

# Then, use that to get implementation details
impl = ai_call(cli="codex", prompt=f"Given this architecture:\n{arch.content}\n\nList implementation steps...")
```

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

## Tool Reference

### ai_spawn

Spawn an AI CLI asynchronously:

```python
job = ai_spawn(
    cli="claude",           # "claude", "codex", or "gemini"
    prompt="Your question",
    files=["src/file.py"],  # Optional: files to include as context
    timeout=300             # Max seconds for CLI to complete
)
# Returns: AISpawnResult with status="spawned", job_id, cli
```

### ai_fetch

Fetch result of spawned AI:

```python
result = ai_fetch(
    job_id="abc123",  # From ai_spawn
    timeout=30        # Seconds to wait (0 = instant check)
)
# Returns AIFetchResult with one of:
# status="completed", content="...", metadata={...}
# status="running", message="Job still running..."
# status="failed", error="..."
# status="timeout", error="CLI timed out..."
```

### ai_call

Synchronous call:

```python
result = ai_call(
    cli="claude",
    prompt="Your question",
    files=["src/file.py"],
    timeout=300
)
# Blocks until complete
# Returns: AICallResult with status="success", content="...", metadata={...}
```

### ai_review

Spawn all 3 CLIs in parallel:

```python
review = ai_review(
    prompt="Analyze this code...",
    files=["src/"],
    timeout=300
)
# Returns: AIReviewResult with jobs dict containing claude, codex, gemini job info
```

### ai_list

List all active jobs:

```python
jobs = ai_list()
# Returns: AIListResult with list of AIJobInfo objects
```

## Sub-Agent Delegation

For complex workflows, delegate to specialized sub-agents. They support parallel execution via the AI tools.

### Available Sub-Agents

| Sub-Agent               | Use Case                        | Uses Parallel AI |
| ----------------------- | ------------------------------- | ---------------- |
| `consensus`             | Multi-model perspective         | Yes              |
| `debugger`              | Root cause investigation        | Yes              |
| `planner`               | Project planning                | Yes              |
| `thinkdeep`             | Extended thinking/analysis      | Yes              |
| `tracer`                | Execution flow analysis         | Yes              |
| `precommit`             | Pre-commit validation           | Yes              |
| `code-reviewer`         | Code quality review             | No               |
| `security-auditor`      | Security vulnerability analysis | No               |
| `test-analyzer`         | Test coverage and quality       | No               |

### When to Delegate vs Direct Tools

**Delegate to sub-agent:**
- Complex analysis needing specialized focus
- When you want structured findings with confidence scores
- Multi-model workflows with synthesis

**Use direct ai_spawn/ai_fetch:**
- Quick multi-model questions
- Custom parallel workflows
- Ad-hoc consensus building

## Patterns

### Quick Consensus

```python
# Spawn all 3 for same question
review = ai_review(prompt="Should we use WebSockets or SSE for real-time updates?")

# Fetch and compare
results = {
    "claude": ai_fetch(review.jobs["claude"].job_id, timeout=120),
    "codex": ai_fetch(review.jobs["codex"].job_id, timeout=120),
    "gemini": ai_fetch(review.jobs["gemini"].job_id, timeout=120),
}

# Synthesize: look for agreement, note disagreements
```

### Specialized Perspectives

```python
# Different prompts for different strengths
claude_job = ai_spawn(
    cli="claude",
    prompt="Analyze the architecture implications of using Redis for caching..."
)
codex_job = ai_spawn(
    cli="codex",
    prompt="Review the Redis integration code for bugs and anti-patterns...",
    files=["src/cache/"]
)
gemini_job = ai_spawn(
    cli="gemini",
    prompt="Research Redis caching best practices and common pitfalls..."
)
```

### Security Audit

```python
security_prompt = """
Review src/auth/ for security vulnerabilities.
Focus on: injection, auth bypass, data exposure.
Output: List findings with severity and file:line references.
"""

claude_job = ai_spawn(cli="claude", prompt=security_prompt, files=["src/auth/"])
codex_job = ai_spawn(cli="codex", prompt=security_prompt, files=["src/auth/"])

# Aggregate findings from both
```

## Writing Good Prompts

When using AI tools, include:

1. **Clear task description** - what exactly to do
2. **Expected output format** - how to structure the response
3. **Scope boundaries** - what files/areas to focus on
4. **Read-only reminder** (for codex/gemini) - they cannot modify anything

### Good Example

```text
Review the authentication module for security vulnerabilities.

Focus on: src/auth/*.py
Output: List of findings with severity (high/medium/low) and line numbers
Constraints: This is a read-only review - identify issues only
```

### Bad Example

```text
Look at the code and tell me what you think
```

## Tips

- **Use parallel for multi-model**: `ai_spawn` + `ai_fetch` is 3x faster than sequential
- **Be specific**: Include file paths, error messages, and context
- **Use appropriate CLI**: codex for code review, gemini for web search
- **Delegate complex work**: Use sub-agents for structured analysis
- **Remember read-only**: Codex and Gemini cannot execute commands or modify files
- **Include files**: Use the `files` parameter to provide code context
- **Monitor jobs**: Use `ai_list()` to check status of all running jobs
