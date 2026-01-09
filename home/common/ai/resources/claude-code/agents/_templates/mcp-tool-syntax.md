# MCP Tool Syntax Reference

Detailed reference for orchestrating multi-model analysis using MCP tools.

## Available Tools

| Tool | Purpose |
|------|---------|
| `mcp__orchestrator__ai_spawn` | Start AI asynchronously, get job_id |
| `mcp__orchestrator__ai_fetch` | Get result from spawned AI |
| `mcp__orchestrator__ai_call` | Synchronous AI call (blocks until complete) |
| `mcp__orchestrator__ai_review` | Spawn all 3 CLIs in parallel |
| `mcp__orchestrator__ai_list` | List all running/completed jobs |

## Parallel Multi-Model Pattern

```python
# 1. Spawn all 3 models with identical prompt
claude_job = mcp__orchestrator__ai_spawn(cli="claude", prompt=analysis_prompt, files=target_files)
codex_job = mcp__orchestrator__ai_spawn(cli="codex", prompt=analysis_prompt, files=target_files)
gemini_job = mcp__orchestrator__ai_spawn(cli="gemini", prompt=analysis_prompt, files=target_files)

# 2. Fetch results (running in parallel, total time = slowest model)
claude_result = mcp__orchestrator__ai_fetch(job_id=claude_job.job_id, timeout=120)
codex_result = mcp__orchestrator__ai_fetch(job_id=codex_job.job_id, timeout=120)
gemini_result = mcp__orchestrator__ai_fetch(job_id=gemini_job.job_id, timeout=120)

# 3. Synthesize findings
```

## ai_spawn Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `cli` | string | "claude", "codex", or "gemini" |
| `prompt` | string | The analysis prompt |
| `files` | list | File paths to include as context |
| `timeout` | int | Max seconds for CLI to complete (default: 300) |

Returns: `AISpawnResult` with `status`, `job_id`, `cli`

## ai_fetch Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `job_id` | string | Job ID from ai_spawn |
| `timeout` | int | Seconds to wait (0 = instant check) |

Returns: `AIFetchResult` with one of:
- `status="completed"`, `content`, `metadata`
- `status="running"`, `message`
- `status="failed"`, `error`
- `status="timeout"`, `error`

## Alternative: ai_review

For convenience, spawn all 3 with one call:

```python
review = mcp__orchestrator__ai_review(prompt=analysis_prompt, files=target_files, timeout=300)
# Returns: AIReviewResult with jobs dict containing claude, codex, gemini job info

# Then fetch each:
claude_result = mcp__orchestrator__ai_fetch(job_id=review.jobs["claude"].job_id, timeout=120)
```

## CLI Capabilities

| CLI | Role | Mode | Use For |
|-----|------|------|---------|
| claude | Worker | Full | Any tool/command execution |
| codex | Reviewer | Read-only | Code review, analysis |
| gemini | Researcher | Read-only | Web search, docs lookup |

**Important**: Codex and Gemini are read-only. Include this in prompts when appropriate.
