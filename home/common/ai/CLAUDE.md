# AI Agent Configurations

Nix configurations for AI CLI tools (Claude Code, OpenCode, Codex CLI, Gemini
CLI).

## Resource Architecture

Shared resources live in `resources/agents/`, tool-specific resources in
`resources/<tool>/`.

```
resources/
├── agents/              # Shared across all AI tools
│   ├── rules/           # 17 global rules → deployed to ~/.claude/rules/ and ~/.config/opencode/rules/
│   └── skills/          # 19 skills → deployed to ~/.agents/skills/ (agentskills.io standard)
├── claude-code/         # Claude Code-specific
│   ├── agents/          # CC-specific agents (subagents, team teammates)
│   ├── commands/        # CC-specific slash commands
│   ├── config/          # CC-specific config files
│   ├── gsd/             # Get Shit Done framework
│   ├── memory/          # Memory files
│   └── scripts/         # Hooks (PreToolUse, PostToolUse, etc.)
├── opencode/            # OpenCode-specific
│   ├── agents/          # OC-specific agents
│   ├── commands/        # OC-specific slash commands
│   └── plugins/         # OC-specific plugins
├── codex/               # OpenAI Codex-specific
│   ├── agents/          # Codex agents (TOML format)
│   ├── skills/          # Codex skills (invokable with $skill-name)
│   └── scripts/hooks/   # Codex lifecycle hooks
└── gemini/              # Gemini CLI-specific
```

### Deployment Paths

| Resource        | Source                            | Deployed to                    |
| --------------- | --------------------------------- | ------------------------------ |
| Skills (shared) | `resources/agents/skills/`        | `~/.agents/skills/`            |
| Rules (CC)      | `resources/agents/rules/`         | `~/.claude/rules/`             |
| Rules (OC)      | `resources/agents/rules/`         | `~/.config/opencode/rules/`    |
| Rules (Codex)   | `resources/agents/rules/`         | `~/.codex/AGENTS.md` (concat)  |
| Commands (CC)   | `resources/claude-code/commands/` | `~/.claude/commands/`          |
| Commands (OC)   | `resources/opencode/commands/`    | `~/.config/opencode/commands/` |
| Agents (Codex)  | `resources/codex/agents/`         | `~/.codex/agents/`             |
| Skills (Codex)  | `resources/codex/skills/`         | `~/.codex/skills/`             |

### Key Design Decisions

- **Skills use the `.agents` standard**
  ([agentskills.io](https://agentskills.io)) — discovered by Claude Code,
  OpenCode, Cursor, Gemini CLI, and 30+ agents
- **Rules are global** — single source in `resources/agents/rules/`, deployed to
  each tool's expected path
- **Commands stay tool-specific** — no cross-agent standard exists for slash
  commands
- **`OPENCODE_DISABLE_CLAUDE_CODE=1`** is set to prevent OpenCode from also
  scanning `~/.claude/` (avoids duplicate skill/rule loading)

---

## Authoring Guide: Commands, Skills, Agents, Rules, Hooks

### Core Principles (All Types)

**Context is precious.** The context window is shared with system prompt,
conversation, tools, and user requests. Every token must justify its cost.

**Prefer examples over explanations.** A well-chosen example teaches faster than
paragraphs of description.

**Match freedom to fragility:**

- **High freedom** (text guidance): When multiple valid approaches exist
- **Medium freedom** (pseudocode/templates): When a preferred pattern exists
- **Low freedom** (exact scripts): When operations are fragile or consistency is
  critical

---

### Skills (`resources/agents/skills/`)

Skills follow the [Agent Skills Standard](https://agentskills.io) — a portable
format supported by 30+ agents.

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

**Best practices:**

- Description is the trigger mechanism — be comprehensive
- Move detailed content to `references/` to avoid bloating context
- Keep SKILL.md under 500 lines
- No README, CHANGELOG, or auxiliary docs — only what the agent needs

---

### Rules (`resources/agents/rules/`)

Rules are always-loaded instructions deployed to all agents. They shape behavior
globally.

**Characteristics:**

- Short (under 50 lines ideal)
- Imperative statements
- No elaboration beyond essentials
- Optional `paths:` frontmatter for conditional loading (e.g., `paths: **/*.go`)

**Example with conditional path:**

```markdown
---
paths: **/*.tf
---

# Terraform Development Rules

- Always check latest provider version before specifying version constraints
- Never guess resource argument names — consult official docs first
```

**Best practices:**

- Rules are always in context — every line costs tokens
- Use bullet points for quick scanning
- No examples unless absolutely necessary (use skills for that)

---

### Commands (tool-specific)

Commands are slash commands. No cross-agent standard exists, so they live in
tool-specific directories.

- Claude Code: `resources/claude-code/commands/`
- OpenCode: `resources/opencode/commands/`

---

### Agents (tool-specific)

Agents are specialized subagents. They live in tool-specific directories.

- Claude Code: `resources/claude-code/agents/`
- OpenCode: `resources/opencode/agents/`

---

### Hooks (`resources/claude-code/scripts/hooks/`)

Hooks are Claude Code-specific scripts that run at lifecycle events.

**Hook types:**

- `PreToolUse/` — Before tool execution (can block)
- `PostToolUse/` — After tool execution
- `SessionStart/` — When a session begins
- `Stop/` — When session ends

---

### Context Efficiency

For detailed token optimization patterns, see
`skills/skill-creator/references/context-efficiency.md`.

**Key budgets:** | Component | Target | |-|-| | Rules | ~500 tokens (always
loaded) | | Skill SKILL.md | ~500 tokens | | References | ~300 tokens each |

---

## Nix Registration (Required)

**All new resources must be registered in Nix** to be deployed:

1. **Skills**: Auto-discovered from `resources/agents/skills/` by
   `orchestrator.nix`
2. **Rules**: Auto-discovered from `resources/agents/rules/` by
   `claude-code.nix` and `opencode.nix`
3. **Commands, Agents**: Auto-discovered from tool-specific dirs by each tool's
   `.nix` module
4. **Hooks**: Register in `claude-code.nix` under the appropriate hook type

New files must be committed before Nix can see them (flakes only track
git-tracked files).
