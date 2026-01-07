# AI Agent Configurations

Nix configurations for AI CLI tools (Claude Code, Codex CLI, Gemini CLI).

## Role Hierarchy

| CLI    | Role         | Mode      | Purpose                          |
| ------ | ------------ | --------- | -------------------------------- |
| claude | Orchestrator | Full      | Primary agent, spawns workers    |
| codex  | Worker       | Read-only | Code review, analysis            |
| gemini | Worker       | Read-only | Web search, documentation lookup |

## Orchestrator MCP Tools

The orchestrator MCP server (`scripts/orchestrator-mcp-server.py`) provides:

- `tmux_*` - Terminal window automation
- `ai_call` - Synchronous AI CLI call
- `ai_spawn` / `ai_fetch` - Async AI CLI (parallel execution)
- `ai_list` - List AI jobs
- `ai_review` - Spawn all 3 CLIs in parallel

## Creating New Skills

When creating new skills for Claude Code, use the `skill-creator` skill. It provides:

- Guidelines for effective skill design
- Progressive disclosure patterns for context efficiency
- Utility scripts: `init_skill.py`, `package_skill.py`, `quick_validate.py`

Skills location: `resources/claude-code/skills/`
