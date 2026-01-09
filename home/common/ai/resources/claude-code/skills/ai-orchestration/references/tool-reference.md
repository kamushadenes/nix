# AI Orchestration Tool Reference

## ai_spawn

```python
job = ai_spawn(
    cli="claude",           # "claude", "codex", or "gemini"
    prompt="Your question",
    files=["src/file.py"],  # Optional context
    timeout=300
)
# Returns: AISpawnResult {status, job_id, cli}
```

## ai_fetch

```python
result = ai_fetch(job_id="abc123", timeout=30)
# Returns AIFetchResult:
# status="completed" → content, metadata
# status="running" → message
# status="failed" → error
# status="timeout" → error
```

## ai_call (Synchronous)

```python
result = ai_call(cli="claude", prompt="...", files=["..."], timeout=300)
# Blocks until complete
```

## ai_review

```python
review = ai_review(prompt="...", files=["src/"], timeout=300)
# Spawns claude, codex, gemini in parallel
# Returns: AIReviewResult with jobs dict
```

## Patterns

### Quick Consensus

```python
review = ai_review(prompt="WebSockets vs SSE for real-time?")
results = {cli: ai_fetch(review.jobs[cli].job_id, 120) for cli in ["claude", "codex", "gemini"]}
```

### Specialized Perspectives

```python
claude_job = ai_spawn(cli="claude", prompt="Architecture implications...")
codex_job = ai_spawn(cli="codex", prompt="Review for bugs...", files=["src/"])
gemini_job = ai_spawn(cli="gemini", prompt="Research best practices...")
```

### Security Audit

```python
prompt = "Review src/auth/ for vulnerabilities. Output: severity, file:line"
claude = ai_spawn(cli="claude", prompt=prompt, files=["src/auth/"])
codex = ai_spawn(cli="codex", prompt=prompt, files=["src/auth/"])
```

## Good Prompts

Include: task description, expected output format, scope boundaries, read-only reminder (for codex/gemini)

```text
Review auth module for security vulnerabilities.
Focus: src/auth/*.py
Output: Findings with severity (high/medium/low) and line numbers
Constraints: Read-only review - identify issues only
```
