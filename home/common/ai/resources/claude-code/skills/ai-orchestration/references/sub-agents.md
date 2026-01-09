# Sub-Agent Delegation

For complex workflows, delegate to specialized sub-agents via the Task tool.

## Available Sub-Agents

| Sub-Agent | Use Case | Multi-Model |
|-----------|----------|-------------|
| `consensus` | Multi-model perspective | Yes |
| `debugger` | Root cause investigation | Yes |
| `planner` | Project planning | Yes |
| `thinkdeep` | Extended analysis | Yes |
| `tracer` | Execution flow analysis | Yes |
| `precommit` | Pre-commit validation | Yes |
| `code-reviewer` | Code quality review | No |
| `security-auditor` | Security analysis | No |
| `test-analyzer` | Test coverage | No |

## When to Delegate vs Direct Tools

**Delegate to sub-agent:**
- Complex analysis needing specialized focus
- Structured findings with confidence scores
- Multi-model workflows with synthesis

**Use direct ai_spawn/ai_fetch:**
- Quick multi-model questions
- Custom parallel workflows
- Ad-hoc consensus building
