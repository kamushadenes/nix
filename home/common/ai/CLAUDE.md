# AI Agent Configurations

This directory contains Nix configurations for AI CLI tools and their integrations.

## Structure

```
ai/
├── claude-code.nix      # Claude Code (Anthropic) - primary orchestrator
├── codex-cli.nix        # Codex CLI (OpenAI) - read-only worker
├── gemini-cli.nix       # Gemini CLI (Google) - read-only worker
├── mcp-servers.nix      # Shared MCP server definitions
└── resources/claude-code/
    ├── commands/        # Custom slash commands
    ├── memory/          # Global CLAUDE.md content
    ├── rules/           # Behavioral rules (loaded into ~/.claude/rules/)
    ├── scripts/         # MCP server implementations
    └── skills/          # Skills teaching tool usage
```

## Role Hierarchy

| CLI    | Role         | Mode      | Purpose                          |
| ------ | ------------ | --------- | -------------------------------- |
| claude | Orchestrator | Full      | Primary agent, spawns workers    |
| codex  | Worker       | Read-only | Code review, analysis            |
| gemini | Worker       | Read-only | Web search, documentation lookup |

## Key Files

### mcp-servers.nix

Unified MCP server configuration with transformation functions:

- `toClaudeCode` - JSON with type/url/command
- `toCodex` - TOML format (uses mcp-remote for HTTP)
- `toGemini` - JSON with httpUrl field

Handles secret placeholders (`@SECRET@`) and agenix integration.

### Orchestrator MCP Server

`resources/claude-code/scripts/orchestrator-mcp-server.py` provides:

- `tmux_*` tools - Terminal window automation
- `ai_*` tools - AI CLI orchestration (spawn, fetch, stream, messaging)

Security: Codex runs with `-s read-only`, Gemini with `--sandbox`.

## Adding New AI CLIs

1. Create `<cli-name>.nix` following existing patterns
2. Import `mcp-servers.nix` for shared MCP config
3. Add transformation function to `mcp-servers.nix` if format differs
4. Update `home.nix` imports
5. Add to orchestrator role hierarchy if it will be spawned as worker
