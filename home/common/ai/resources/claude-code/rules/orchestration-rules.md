# AI Orchestration Rules

## Role Hierarchy

Claude Code is the **orchestrator**. When calling external AI agents via orchestrator MCP:

| CLI    | Role        | Mode      | Capabilities                       |
| ------ | ----------- | --------- | ---------------------------------- |
| claude | Worker/Peer | Full      | Can execute any tool/command       |
| codex  | Reviewer    | Read-only | Code review, analysis, suggestions |
| gemini | Researcher  | Read-only | Web search, documentation lookup   |

## Sub-Agent Delegation

For complex workflows, delegate to specialized Claude Code sub-agents. Sub-agents are in `~/.claude/agents/`:

| Sub-Agent               | Purpose                     |
| ----------------------- | --------------------------- |
| `code-reviewer`         | Code quality review         |
| `security-auditor`      | Security analysis           |
| `test-analyzer`         | Test coverage analysis      |
| `documentation-writer`  | Docs quality review         |
| `silent-failure-hunter` | Error handling gaps         |
| `performance-analyzer`  | Performance issues          |
| `type-checker`          | Type safety analysis        |
| `refactoring-advisor`   | Refactoring opportunities   |
| `code-simplifier`       | Complexity reduction        |
| `comment-analyzer`      | Comment quality             |
| `dependency-checker`    | Dependency health           |
| `consensus`             | Multi-model perspectives    |
| `debugger`              | Root cause investigation    |
| `planner`               | Project planning            |
| `precommit`             | Pre-commit validation       |
| `thinkdeep`             | Extended thinking/analysis  |
| `tracer`                | Execution flow analysis     |

## Using Orchestrator AI Tools

The orchestrator MCP provides tools for parallel AI CLI orchestration:

### Synchronous Call (ai_call)

```python
# Blocking call - waits for result
result = ai_call(
    cli="codex",  # or "claude" or "gemini"
    prompt="Review this code for security issues",
    files=["src/auth/"]  # optional file context
)
# result.status, result.content, result.metadata
```

### Parallel Execution (ai_spawn + ai_fetch)

```python
# Spawn multiple CLIs in parallel
claude_job = ai_spawn(cli="claude", prompt="Analyze architecture")
codex_job = ai_spawn(cli="codex", prompt="Review for bugs")
gemini_job = ai_spawn(cli="gemini", prompt="Research best practices")

# Fetch results (all running in parallel)
claude_result = ai_fetch(job_id=claude_job.job_id, timeout=120)
codex_result = ai_fetch(job_id=codex_job.job_id, timeout=120)
gemini_result = ai_fetch(job_id=gemini_job.job_id, timeout=120)
```

### Multi-Model Review (ai_review)

```python
# Convenience: spawns all 3 CLIs with same prompt
review = ai_review(prompt="Review this function", files=["src/main.py"])
# Returns job_ids for claude, codex, and gemini
```

## Enforced Constraints

### Codex and Gemini: Read-Only Mode

- These agents **cannot** modify files, run builds, or execute commands
- Use them for: reviews, analysis, research, validation

### Claude Workers: Full Access

- Spawned Claude instances can run any tool Claude Code can use
- Use sparingly - only when parallel workers provide clear benefit
- Good for: independent subtasks, parallel analysis, second opinions

## Instruction Requirements

When using external agents (codex/gemini), the prompt **MUST** include:

1. **Clear task description** - what exactly to do
2. **Expected output format** - how to structure the response
3. **Scope boundaries** - what files/areas to focus on
4. **Read-only reminder** - explicit reminder they cannot modify

### Good Prompt Example

```text
Review the authentication module for security vulnerabilities.

Focus on: src/auth/*.py
Output: List of findings with severity (high/medium/low) and line numbers
Constraints: This is a read-only review - do not suggest specific code changes, only identify issues
```

### Bad Prompt Example

```text
Look at the code and tell me what you think
```

## When to Use External Agents

**Multi-model orchestration has latency cost.** Use parallel execution to minimize wait time.

**Do use when:**

- Stuck on a complex bug after initial investigation
- Making major architectural decisions with significant tradeoffs
- Security-critical code that genuinely needs multiple perspectives
- Debugging issues that have resisted initial analysis

**Don't use when:**

- Simple, straightforward tasks (most work)
- Already confident in approach
- Just need to execute a known solution
- Minor refactoring or code cleanup
- Single-file changes with clear scope

**Default behavior**: Claude Code should make its own decisions for most work. Only escalate to multi-model consensus when the complexity genuinely warrants it.

## Sub-Agents That Use Multi-Model (Use Sparingly)

These sub-agents call external AI models:

| Sub-Agent    | When to Use                                       |
| ------------ | ------------------------------------------------- |
| `consensus`  | When you need multiple perspectives on a decision |
| `debugger`   | Complex bugs that resist initial investigation    |
| `planner`    | Large multi-phase projects                        |
| `precommit`  | Optional quick sanity check before commits        |
| `thinkdeep`  | Problems requiring extended analysis              |
| `tracer`     | Complex execution flow analysis                   |

**Most code reviews should use `code-reviewer` directly** rather than multi-model consensus.
