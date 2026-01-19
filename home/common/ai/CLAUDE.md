# AI Agent Configurations

Nix configurations for AI CLI tools (Claude Code, Codex CLI, Gemini CLI).

## Role Hierarchy

| CLI    | Role       | Mode      | Purpose                          |
| ------ | ---------- | --------- | -------------------------------- |
| claude | Worker     | Full      | Any tool/command                 |
| codex  | Reviewer   | Read-only | Code review, analysis            |
| gemini | Researcher | Read-only | Web search, documentation lookup |

## Orchestrator MCP Tools

The orchestrator MCP server (`scripts/orchestrator-mcp-server.py`) provides:

- `tmux_*` - Terminal window automation
- `ai_call` - Synchronous AI CLI call
- `ai_spawn` / `ai_fetch` - Async AI CLI (parallel execution)
- `ai_list` - List AI jobs
- `ai_review` - Spawn all 3 CLIs in parallel

---

## Authoring Guide: Commands, Skills, Agents, Rules, Hooks

### Core Principles (All Types)

**Context is precious.** The context window is shared with system prompt, conversation, tools, and user requests. Every token must justify its cost.

**Claude is already smart.** Only add information Claude doesn't have: domain-specific procedures, company knowledge, exact tool syntax, or guardrails for fragile operations.

**Prefer examples over explanations.** A well-chosen example teaches faster than paragraphs of description.

**Match freedom to fragility:**
- **High freedom** (text guidance): When multiple valid approaches exist
- **Medium freedom** (pseudocode/templates): When a preferred pattern exists
- **Low freedom** (exact scripts): When operations are fragile or consistency is critical

---

### Commands (`resources/claude-code/commands/`)

Commands are user-invocable slash commands (e.g., `/commit`, `/deep-review`).

**File format:**
```markdown
---
allowed-tools: Bash(git:*), Read, Task  # Tools the command can use
description: One-line description       # Shown in /help
---

## Context (optional)
- Current state: !`git status`  # Shell expansion for dynamic context

## Your task
[Instructions for Claude]
```

**Patterns:**

1. **Simple automation** - Few tools, direct action:
   ```markdown
   ---
   allowed-tools: Bash(git add:*), Bash(git commit:*)
   description: Create a git commit
   ---
   Based on the above changes, create a single git commit.
   Do not use any other tools or send any other text.
   ```

2. **Multi-step workflow** - User choices, conditional logic:
   ```markdown
   ## Steps
   1. **Ask user** using AskUserQuestion:
      - Option A: ...
      - Option B: ...
   2. **If option A**: [steps]
   3. **If option B**: [steps]
   ```

3. **Agent delegation** - Complex tasks via Task tool:
   ```markdown
   Use the **Task tool** with `subagent_type='general-purpose'` to:
   1. [Step]
   2. [Step]
   ```

**Best practices:**
- Use `!`backticks`` for shell expansion to inject dynamic context
- Restrict tools to minimum needed via `allowed-tools`
- End with clear output format or "do not send any other text"
- For complex commands, delegate to agents via Task tool

---

### Skills (`resources/claude-code/skills/`)

Skills provide specialized knowledge and workflows. Use the `skill-creator` skill for guided creation.

**Directory structure:**
```
skill-name/
├── SKILL.md           # Required: metadata + instructions
├── scripts/           # Optional: executable code
├── references/        # Optional: documentation loaded on-demand
└── assets/            # Optional: templates, images for output
```

**SKILL.md format:**
```markdown
---
name: skill-name
description: What it does. Use when [specific triggers]. (1-2 sentences)
---

# Skill Name

[Core instructions - under 500 lines]

## Advanced Features
- **Topic A**: See [references/topic-a.md]
- **Topic B**: See [references/topic-b.md]
```

**Key patterns:**

1. **Progressive disclosure** - Keep SKILL.md lean, reference files for details:
   ```markdown
   ## Quick Start
   [Essential workflow]

   ## Details
   - Concurrency: See `references/concurrency.md`
   - Testing: See `references/testing.md`
   ```

2. **Domain organization** - Split by variant:
   ```
   references/
   ├── aws.md     # Only loaded for AWS work
   ├── gcp.md     # Only loaded for GCP work
   └── azure.md   # Only loaded for Azure work
   ```

3. **MUST DO / MUST NOT** - Clear guardrails:
   ```markdown
   ## MUST DO
   - Format with `gofmt`
   - Handle all errors explicitly

   ## MUST NOT
   - Ignore errors with bare `_`
   - Use `panic()` for error handling
   ```

**Best practices:**
- Description is the trigger mechanism - be comprehensive
- Move detailed content to `references/` to avoid bloating context
- Include scripts for repetitive code that would be rewritten each time
- No README, CHANGELOG, or auxiliary docs - only what the agent needs

---

### Agents (`resources/claude-code/agents/`)

Agents are specialized subagents invoked via Task tool.

**File format:**
```markdown
---
name: agent-name
description: Brief description. Use [when/triggers].
tools: Read, Grep, Glob, Bash, mcp__orchestrator__ai_spawn
model: opus  # or sonnet, haiku
---

> **References**: Link to templates/references

## Domain Prompt
[What to analyze and how]

## Methodology
1. Step one
2. Step two

## Report Format
[Expected output structure]
```

**Agent types:**

1. **Direct analyzer** - Reads code and produces findings:
   ```markdown
   ## Domain Prompt
   Review this code for:
   1. Issue type A
   2. Issue type B

   Provide findings with:
   - Severity
   - File:line references
   - Fix recommendations
   ```

2. **Multi-model orchestrator** - Spawns claude/codex/gemini in parallel:
   ```markdown
   > **Orchestration:** Follow `_templates/orchestrator-base.md`

   **STOP. DO NOT analyze code yourself.**
   Your ONLY job is to spawn 3 AI models and synthesize.

   ## Workflow
   1. Identify files via Glob
   2. Spawn 3 models with domain prompt
   3. Fetch results
   4. Synthesize into unified report
   ```

**Best practices:**
- Reference shared templates (`_templates/`) for common patterns
- Include severity levels and report format
- For orchestrators: explicitly forbid direct analysis
- Scoped feedback: only review what changed, no unrelated suggestions

---

### Rules (`resources/claude-code/rules/`)

Rules are always-loaded instructions that shape Claude's behavior.

**Characteristics:**
- Short (under 50 lines ideal)
- Imperative statements
- No elaboration beyond essentials

**Good rule structure:**
```markdown
# Domain Rules

## Section
- Rule one
- Rule two

## Another Section
- Rule three
```

**Examples:**

1. **Workflow rules** - Process guidance:
   ```markdown
   ## Planning Mode
   - Shift+Tab enters plan mode
   - Exit before making changes
   - Run `/plan-to-tasks` after completing plan
   ```

2. **Tool rules** - When/how to use tools:
   ```markdown
   ## When to Use Multi-Model
   **Use when:**
   - Stuck on complex bugs
   - Major architectural decisions

   **Don't use when:**
   - Simple tasks
   - Already confident in approach
   ```

3. **Constraint rules** - Hard limits:
   ```markdown
   ## Commit Messages
   - Use conventional commit format
   - Keep messages concise
   ```

**Best practices:**
- Rules are always in context - every line costs tokens
- Use tables for structured information
- Bullet points for quick scanning
- No examples unless absolutely necessary (use skills for that)

---

### Hooks (`resources/claude-code/scripts/hooks/`)

Hooks are scripts that run at specific events.

**Hook types:**
- `PreToolUse/` - Before tool execution (can block)
- `PostToolUse/` - After tool execution
- `SessionStart/` - When a session begins
- `Stop/` - When session ends

**PreToolUse pattern (blocking):**
```python
#!/usr/bin/env python3
import json
import sys

input_data = json.load(sys.stdin)
tool_name = input_data.get("tool_name", "")
tool_input = input_data.get("tool_input") or {}
command = tool_input.get("command", "")

if should_block(command):
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": "Reason for blocking"
        }
    }
    print(json.dumps(output))
    sys.exit(0)

# Allow: exit with no output
sys.exit(0)
```

**PostToolUse pattern (formatting):**
```bash
#!/usr/bin/env bash
# Format files after Write/Edit

tool_name="$TOOL_NAME"
file_path="$FILE_PATH"

if [[ "$tool_name" =~ ^(Write|Edit)$ ]] && [[ "$file_path" == *.go ]]; then
    gofmt -w "$file_path"
fi
```

**Best practices:**
- Exit 0 with JSON output to block, exit 0 with no output to allow
- Use allowlists for safe patterns before blocklists
- Include clear reasons in denial messages
- PostToolUse hooks should be idempotent

---

### Context Efficiency

For detailed token optimization patterns, see `skills/skill-creator/references/context-efficiency.md`.

**Key budgets:**
| Component | Target |
|-----------|--------|
| Rules | ~500 tokens (always loaded) |
| Agent body | 400-600 tokens |
| Skill SKILL.md | ~500 tokens |
| References | ~300 tokens each |

**Shared templates:** `agents/_templates/` for orchestration patterns, `agents/_references/` for domain knowledge.

---

## Quick Reference

| Type    | Location                        | Trigger              | Context Load |
| ------- | ------------------------------- | -------------------- | ------------ |
| Command | `commands/`                     | `/command-name`      | On invoke    |
| Skill   | `skills/*/SKILL.md`             | Auto (via desc)      | On match     |
| Agent   | `agents/`                       | Task tool            | On spawn     |
| Rule    | `rules/`                        | Always               | Always       |
| Hook    | `scripts/hooks/{Pre,Post,SessionStart,Stop}` | Tool/event lifecycle | N/A          |

---

## Nix Registration (Required)

**All new resources must be registered in Nix** to be deployed. After creating any command, skill, agent, rule, or hook:

1. **Commands, Agents, Rules**: Register in `claude-code.nix`
2. **Skills**: Register in `orchestrator.nix`
3. **Hooks**: Register in `claude-code.nix` under the appropriate hook type

Example skill registration in `orchestrator.nix`:
```nix
".claude/skills/my-skill/SKILL.md".source = "${skillsDir}/my-skill/SKILL.md";
```

Without Nix registration, resources won't be symlinked to `~/.claude/` and won't be available.
