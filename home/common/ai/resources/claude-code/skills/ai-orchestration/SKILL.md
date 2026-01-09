---
name: ai-orchestration
description: Multi-model AI collaboration via orchestrator MCP. Use when seeking second opinions, debugging complex issues, building consensus on architectural decisions, conducting code reviews, or needing external validation on analysis.
triggers: second opinion, multi-model, consensus, external AI, codex, gemini, model comparison, AI collaboration, expert validation, parallel AI, ai_spawn, ai_fetch
---

# AI CLI Orchestration

Query external AI models (claude, codex, gemini) for second opinions and consensus building.

## Tools

| Tool | Description |
|------|-------------|
| `ai_call` | Synchronous - wait for result |
| `ai_spawn` | Async - start background job, get job_id |
| `ai_fetch` | Get result from spawned job |
| `ai_review` | Spawn all 3 CLIs in parallel |
| `ai_list` | List running/completed jobs |

## Role Hierarchy

| CLI | Mode | Use For |
|-----|------|---------|
| claude | Full | Any tool/command |
| codex | Read-only | Code review, analysis |
| gemini | Read-only | Web search, docs |

## Parallel Execution (Recommended)

```python
# Spawn all 3, fetch results - total time = slowest (~60s) not sum (~180s)
review = ai_review(prompt="...", files=["src/"])
claude = ai_fetch(job_id=review.jobs["claude"].job_id, timeout=120)
codex = ai_fetch(job_id=review.jobs["codex"].job_id, timeout=120)
gemini = ai_fetch(job_id=review.jobs["gemini"].job_id, timeout=120)
```

## When to Use

**Do**: Stuck on complex bugs, architectural decisions, security-sensitive code, need diverse perspectives
**Don't**: Simple tasks, confident in approach, executing known solutions

## References

- **Tool parameters and patterns**: See `references/tool-reference.md`
- **Sub-agent delegation**: See `references/sub-agents.md`
