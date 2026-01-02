---
name: ai-orchestration
description: Multi-model AI collaboration via orchestrator MCP. Use when seeking second opinions, debugging complex issues, building consensus on architectural decisions, conducting code reviews, or needing external validation on analysis.
---

# AI CLI Orchestration

Query external AI models (claude, codex, gemini) for second opinions, debugging, consensus building, and expert validation. The orchestrator MCP provides tools to spawn jobs, stream output, and coordinate multi-model workflows.

## Role Hierarchy

Claude Code is the **orchestrator**. When spawning AI agents:

| CLI     | Role            | Mode      | Capabilities                          |
|---------|-----------------|-----------|---------------------------------------|
| claude  | Worker/Peer     | Full      | Can execute any tool/command          |
| codex   | Reviewer        | Read-only | Code review, analysis, suggestions    |
| gemini  | Researcher      | Read-only | Web search, documentation lookup      |

**Enforced by MCP server:**
- Codex always runs with `-s read-only` (cannot modify files)
- Gemini always runs with `--sandbox` (restricted environment)
- Only Claude workers have full execution capabilities

## Quick Reference

| Tool              | Purpose                                        |
|-------------------|------------------------------------------------|
| `ai_spawn`        | Start async AI job, returns job_id immediately |
| `ai_fetch`        | Get job result (blocking or non-blocking)      |
| `ai_stream`       | Get incremental streaming output               |
| `ai_ask`          | Sync query (spawn + wait in one call)          |
| `ai_send`         | Send message to a job (inter-agent messaging)  |
| `ai_receive`      | Get messages for a job                         |
| `ai_review`       | Code review via AI CLI                         |
| `ai_search`       | Web search via gemini or claude                |
| `ai_list`         | List jobs in current session                   |

## When to Use External Models

**Do use when:**
- Stuck on a complex bug after initial investigation
- Making architectural decisions with tradeoffs
- Need validation before major refactoring
- Security-sensitive code needs audit
- Want diverse perspectives on approach

**Don't use when:**
- Simple, straightforward tasks
- Already confident in approach
- Just need to execute known solution

## Basic Workflows

### Quick Question (Synchronous)

```python
# Ask a single model and wait for response
result = ai_ask(
    prompt="What's the best way to handle rate limiting in Python?",
    cli="claude"  # or "codex" or "gemini"
)
```

### Second Opinion (Parallel)

Call `ai_ask` multiple times in parallel to get perspectives from different models:

```python
# Claude Code calls these in parallel
response1 = ai_ask(prompt="Should I use Redis or PostgreSQL for sessions?", cli="claude")
response2 = ai_ask(prompt="Should I use Redis or PostgreSQL for sessions?", cli="codex")
response3 = ai_ask(prompt="Should I use Redis or PostgreSQL for sessions?", cli="gemini")
```

### Code Review

```python
# Use codex's native review (recommended)
result = ai_review(cli="codex", uncommitted=True)

# Or with a specific focus
result = ai_review(cli="codex", uncommitted=True, focus="security")

# Or using claude/gemini (generates diff-based prompt)
result = ai_review(cli="claude", uncommitted=True, focus="performance")
```

### Web Search

```python
# Gemini has native search support
result = ai_search(query="latest Python 3.13 features", cli="gemini")
```

## Advanced Workflows

### Async Spawn/Fetch Pattern

For long-running tasks, spawn jobs and fetch results later:

```python
# Spawn jobs (returns immediately)
job1 = ai_spawn(prompt="Analyze security patterns...", cli="claude")
job2 = ai_spawn(prompt="Analyze security patterns...", cli="codex")
job3 = ai_spawn(prompt="Analyze security patterns...", cli="gemini")

# Do other work while they run...

# Fetch results when ready
result1 = ai_fetch(job1)  # blocks until done
result2 = ai_fetch(job2)
result3 = ai_fetch(job3)
```

### Streaming Output

Monitor a long-running job's progress:

```python
job_id = ai_spawn(prompt="Analyze this large codebase...", cli="claude")

# Poll for incremental output
offset = 0
while True:
    stream = ai_stream(job_id, offset=offset)
    data = json.loads(stream)

    if data["output"]:
        print(data["output"], end="")
        offset = data["offset"]

    if data["done"]:
        break

    time.sleep(1)
```

### Inter-Agent Messaging

Send context or instructions to a running job:

```python
job = ai_spawn(prompt="Review this PR", cli="claude")

# Send additional context
ai_send(job, message="Focus on authentication code", sender="coordinator")
ai_send(job, message="Check for SQL injection", sender="security-agent")

# Later, check messages
messages = ai_receive(job, since=0)
```

## Tool Parameters

### ai_spawn

| Parameter | Type   | Default   | Description                        |
|-----------|--------|-----------|------------------------------------|
| prompt    | str    | required  | The question/task                  |
| cli       | str    | "claude"  | "claude", "codex", or "gemini"     |
| model     | str    | ""        | Optional model override            |
| files     | list   | []        | Files to include as context        |

### ai_fetch

| Parameter | Type   | Default | Description                      |
|-----------|--------|---------|----------------------------------|
| job_id    | str    | required| Job ID from ai_spawn             |
| block     | bool   | true    | Wait for completion              |
| timeout   | int    | 300     | Max wait time in seconds         |

### ai_stream

| Parameter | Type   | Default | Description                      |
|-----------|--------|---------|----------------------------------|
| job_id    | str    | required| Job ID to stream from            |
| offset    | int    | 0       | Byte offset for incremental read |

### ai_review

| Parameter   | Type   | Default | Description                      |
|-------------|--------|---------|----------------------------------|
| cli         | str    | "codex" | "codex" (native), "claude", "gemini" |
| uncommitted | bool   | true    | Review uncommitted changes       |
| base        | str    | ""      | Branch to compare against        |
| focus       | str    | ""      | "security", "performance", "quality" |

## Multi-Model Patterns

### Consensus Building

Spawn same question to all models, compare responses:

```python
# Spawn to all 3 models in parallel
job1 = ai_spawn("Should we use microservices?", cli="claude")
job2 = ai_spawn("Should we use microservices?", cli="codex")
job3 = ai_spawn("Should we use microservices?", cli="gemini")

# Fetch all results
results = [ai_fetch(j) for j in [job1, job2, job3]]

# Synthesize: look for agreement, note disagreements
```

### Security Audit

Run security-focused reviews from multiple perspectives:

```python
# All 3 with security focus
review1 = ai_review(cli="codex", uncommitted=True, focus="security")
review2 = ai_review(cli="claude", uncommitted=True, focus="security")
review3 = ai_review(cli="gemini", uncommitted=True, focus="security")

# Aggregate findings, deduplicate
```

## Session Isolation

Jobs are scoped to the current tmux session:
- Different workspaces have isolated job namespaces
- Jobs from session A cannot see/access jobs from session B
- Use `ai_list()` to see jobs in your current session

## External Monitoring

Use the `orchestrator` CLI from outside tmux:

```bash
# List all sessions with job counts
orchestrator sessions

# List jobs in a session
orchestrator jobs [session-name]

# Get job details
orchestrator status job_abc123

# Stream job output (tail -f style)
orchestrator stream job_abc123 -f

# Kill a running job
orchestrator kill job_abc123

# Clean up old jobs
orchestrator cleanup --age 2  # older than 2 hours
```

## Writing Good Prompts for Agents

When spawning any agent, include:

1. **Clear task description** - what exactly to do
2. **Expected output format** - how to structure the response
3. **Scope boundaries** - what files/areas to focus on
4. **Read-only reminder** (for codex/gemini) - they cannot modify anything

### Good Prompt Example

```
Review the authentication module for security vulnerabilities.

Focus on: src/auth/*.py
Output: List of findings with severity (high/medium/low) and line numbers
Constraints: This is a read-only review - identify issues only, do not suggest code changes
```

### Bad Prompt Example

```
Look at the code and tell me what you think
```

## Tips

- **Be specific**: Include file paths, error messages, and context
- **Use appropriate CLI**: codex for code review, gemini for web search
- **Parallel when possible**: Spawn multiple jobs in parallel for faster results
- **Stream long tasks**: Use ai_stream for visibility into long-running jobs
- **Check job status**: Use ai_list to see running/completed jobs
- **Remember read-only**: Codex and Gemini cannot execute commands or modify files
