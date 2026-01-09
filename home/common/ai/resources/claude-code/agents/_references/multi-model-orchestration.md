# Multi-Model Orchestration Reference

Code patterns for spawning and synthesizing results from claude, codex, and gemini.

## Parallel Execution Pattern

```python
# Build your domain-specific prompt
analysis_prompt = f"""<Your domain prompt here>

Code context:
{context}

Provide findings with:
- Severity: 🔴 Critical, 🟠 High, 🟡 Medium, 🟢 Low
- File:line references
- Clear recommendations"""

# Spawn all 3 models with identical prompts
claude_job = mcp__orchestrator__ai_spawn(cli="claude", prompt=analysis_prompt, files=target_files)
codex_job = mcp__orchestrator__ai_spawn(cli="codex", prompt=analysis_prompt, files=target_files)
gemini_job = mcp__orchestrator__ai_spawn(cli="gemini", prompt=analysis_prompt, files=target_files)

# Fetch all results (they ran in parallel)
claude_result = mcp__orchestrator__ai_fetch(job_id=claude_job.job_id, timeout=120)
codex_result = mcp__orchestrator__ai_fetch(job_id=codex_job.job_id, timeout=120)
gemini_result = mcp__orchestrator__ai_fetch(job_id=gemini_job.job_id, timeout=120)
```

## MCP Tool Calling (IMPORTANT)

**These are MCP tools, NOT bash commands. Call them directly like Read, Grep, or Glob.**

Do NOT use Bash to run these tools. Call them directly as MCP tools.

## Synthesis Rules

Combine findings from all 3 models:

| Agreement | Confidence | Action |
|-----------|------------|--------|
| All 3 agree | High | Prioritize, definite issue |
| 2 of 3 agree | Medium | Should fix |
| Only 1 model | Low | Present for human judgment |
| Unique insight | Variable | Include if valuable |

## Confidence Threshold

Only report issues with confidence >= 80%. Suppress likely false positives.

- 90-100%: Definite issue - must fix
- 80-89%: Likely issue - should fix
- Below 80%: Suppress or note uncertainty

## Report Structure

```markdown
## Analysis Summary

### Consensus Findings (All Models Agree)
[High confidence issues that must be addressed]

### Likely Issues (2+ Models Agree)
[Should be addressed]

### Model-Specific Insights
**Claude**: [unique findings]
**Codex**: [unique findings]
**Gemini**: [unique findings]

### Divergent Opinions
[Present both perspectives for human judgment]
```

## Alternative: ai_review Convenience Tool

For simple same-prompt analysis across all 3 models:

```python
review = ai_review(prompt="Analyze this code...", files=["src/"])

# Fetch results
claude_result = ai_fetch(job_id=review.jobs["claude"].job_id, timeout=120)
codex_result = ai_fetch(job_id=review.jobs["codex"].job_id, timeout=120)
gemini_result = ai_fetch(job_id=review.jobs["gemini"].job_id, timeout=120)
```

## Role Reminder

| CLI | Mode | Best For |
|-----|------|----------|
| claude | Full | Complex analysis, can execute tools |
| codex | Read-only | Code patterns, bugs, quality |
| gemini | Read-only | Best practices, documentation |
