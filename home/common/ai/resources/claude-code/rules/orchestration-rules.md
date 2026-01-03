# AI Orchestration Rules

## Role Hierarchy

Claude Code is the **orchestrator**. When spawning AI agents via the orchestrator MCP:

| CLI    | Role        | Mode      | Capabilities                       |
| ------ | ----------- | --------- | ---------------------------------- |
| claude | Worker/Peer | Full      | Can execute any tool/command       |
| codex  | Reviewer    | Read-only | Code review, analysis, suggestions |
| gemini | Researcher  | Read-only | Web search, documentation lookup   |

## Enforced Constraints

### Codex and Gemini: Read-Only Mode

- Codex runs with `-s read-only` sandbox (enforced by MCP server)
- Gemini runs with `--sandbox` flag (enforced by MCP server)
- These agents **cannot** modify files, run builds, or execute commands
- Use them for: reviews, analysis, research, validation

### Claude Workers: Full Access

- Spawned Claude instances can run any tool Claude Code can use
- Use sparingly - only when parallel workers provide clear benefit
- Good for: independent subtasks, parallel analysis, second opinions

## Instruction Requirements

When spawning any agent, the prompt **MUST** include:

1. **Clear task description** - what exactly to do
2. **Expected output format** - how to structure the response
3. **Scope boundaries** - what files/areas to focus on
4. **Read-only reminder** (for codex/gemini) - explicit reminder they cannot modify

### Good Prompt Example

```
Review the authentication module for security vulnerabilities.

Focus on: src/auth/*.py
Output: List of findings with severity (high/medium/low) and line numbers
Constraints: This is a read-only review - do not suggest specific code changes, only identify issues
```

### Bad Prompt Example

```
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
