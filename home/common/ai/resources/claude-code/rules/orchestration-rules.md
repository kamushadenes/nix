# AI Orchestration Rules

## Role Hierarchy

Claude Code is the **orchestrator**. When calling external AI agents via clink:

| CLI    | Role        | Mode      | Capabilities                       |
| ------ | ----------- | --------- | ---------------------------------- |
| claude | Worker/Peer | Full      | Can execute any tool/command       |
| codex  | Reviewer    | Read-only | Code review, analysis, suggestions |
| gemini | Researcher  | Read-only | Web search, documentation lookup   |

## Sub-Agent Delegation

**IMPORTANT:** For complex workflows, delegate to specialized Claude Code sub-agents instead of calling clink directly. Sub-agents are in `~/.claude/agents/`:

| Sub-Agent               | Purpose                     | Key Tools               |
| ----------------------- | --------------------------- | ----------------------- |
| `code-reviewer`         | Code quality review         | `task_review_complete`  |
| `security-auditor`      | Security analysis           | `task_qa_vote`          |
| `test-analyzer`         | Test coverage               | `task_qa_vote`          |
| `documentation-writer`  | Docs quality                | `task_comment`          |
| `task-discusser`        | Discussion orchestration    | `task_start_discussion` |
| `silent-failure-hunter` | Error handling gaps         | `task_qa_vote`          |
| `performance-analyzer`  | Performance issues          | `task_qa_vote`          |
| `type-checker`          | Type safety                 | `task_qa_vote`          |
| `refactoring-advisor`   | Refactoring opportunities   | `task_comment`          |
| `code-simplifier`       | Complexity reduction        | `task_comment`          |
| `comment-analyzer`      | Comment quality             | `task_comment`          |
| `dependency-checker`    | Dependency health           | `task_comment`          |
| `consensus`             | Multi-model perspectives    | `clink`                 |
| `debugger`              | Root cause investigation    | `clink`                 |
| `planner`               | Project planning            | `clink`                 |
| `precommit`             | Pre-commit validation       | `clink`                 |
| `thinkdeep`             | Extended thinking/analysis  | `clink`                 |
| `tracer`                | Execution flow analysis     | `clink`                 |

Sub-agents report findings via orchestrator MCP tools directly to tasks.

## Using clink for External AI

The `clink` tool bridges to external AI CLIs:

```python
# Query an external model
result = clink(
    prompt="Review this code for security issues",
    cli="codex",  # or "claude" or "gemini"
    files=["src/auth/"]  # optional file context
)
```

**clink is synchronous** - it blocks until the external CLI completes.

## Enforced Constraints

### Codex and Gemini: Read-Only Mode

- These agents **cannot** modify files, run builds, or execute commands
- Use them for: reviews, analysis, research, validation

### Claude Workers: Full Access

- Spawned Claude instances can run any tool Claude Code can use
- Use sparingly - only when parallel workers provide clear benefit
- Good for: independent subtasks, parallel analysis, second opinions

## Instruction Requirements

When using clink for external agents (codex/gemini), the prompt **MUST** include:

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

**Multi-model orchestration is expensive and slow.** Each clink call takes 30-120 seconds. Use sparingly.

**Do use when:**

- Stuck on a complex bug after initial investigation
- Making major architectural decisions with significant tradeoffs
- Security-critical code that genuinely needs multiple perspectives
- Debugging issues that have resisted initial analysis

**Don't use when:**

- Simple, straightforward tasks (most tasks)
- Already confident in approach
- Just need to execute a known solution
- Minor refactoring or code cleanup
- Single-file changes with clear scope

**Default behavior**: Claude Code should make its own decisions for most tasks. Only escalate to multi-model consensus when the complexity genuinely warrants the time cost.

## Sub-Agents That Use clink (Use Sparingly)

These sub-agents call external AI models and are slow:

| Sub-Agent         | When to Use                                        |
| ----------------- | -------------------------------------------------- |
| `task-discusser`  | Major architectural decisions only                 |
| `consensus`       | When you need multiple perspectives on a decision  |
| `debugger`        | Complex bugs that resist initial investigation     |
| `planner`         | Large multi-phase projects                         |
| `precommit`       | Optional quick sanity check before commits         |
| `thinkdeep`       | Problems requiring extended analysis               |
| `tracer`          | Complex execution flow analysis                    |

**Most code reviews should use `code-reviewer` directly** (no clink) rather than multi-model consensus.
