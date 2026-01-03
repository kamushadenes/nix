# AI Orchestration Rules

## Role Hierarchy

Claude Code is the **orchestrator**. When spawning AI agents via the orchestrator MCP:

| CLI    | Role        | Mode      | Capabilities                       |
| ------ | ----------- | --------- | ---------------------------------- |
| claude | Worker/Peer | Full      | Can execute any tool/command       |
| codex  | Reviewer    | Read-only | Code review, analysis, suggestions |
| gemini | Researcher  | Read-only | Web search, documentation lookup   |

## Sub-Agent Delegation

**IMPORTANT:** For complex workflows, delegate to specialized Claude Code sub-agents instead of running them directly. Sub-agents are in `~/.claude/agents/`:

| Sub-Agent               | Purpose                   | Key Tools               |
| ----------------------- | ------------------------- | ----------------------- |
| `code-reviewer`         | Code quality review       | `task_review_complete`  |
| `security-auditor`      | Security analysis         | `task_qa_vote`          |
| `test-analyzer`         | Test coverage             | `task_qa_vote`          |
| `documentation-writer`  | Docs quality              | `task_comment`          |
| `task-discusser`        | Discussion orchestration  | `task_start_discussion` |
| `silent-failure-hunter` | Error handling gaps       | `task_qa_vote`          |
| `performance-analyzer`  | Performance issues        | `task_qa_vote`          |
| `type-checker`          | Type safety               | `task_qa_vote`          |
| `refactoring-advisor`   | Refactoring opportunities | `task_comment`          |
| `code-simplifier`       | Complexity reduction      | `task_comment`          |
| `comment-analyzer`      | Comment quality           | `task_comment`          |
| `dependency-checker`    | Dependency health         | `task_comment`          |

Sub-agents report findings via orchestrator MCP tools directly to tasks.

## Enforced Constraints

### Codex and Gemini: Read-Only Mode

- Codex runs with `-a full-auto` + READ-ONLY instruction
- Gemini runs with `--sandbox` flag
- These agents **cannot** modify files, run builds, or execute commands
- Use them for: reviews, analysis, research, validation

### Claude Workers: Full Access

- Spawned Claude instances can run any tool Claude Code can use
- Use sparingly - only when parallel workers provide clear benefit
- Good for: independent subtasks, parallel analysis, second opinions

## Instruction Requirements

When spawning external agents (codex/gemini), the prompt **MUST** include:

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
