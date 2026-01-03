# Orchestrator MCP Server configuration
#
# Provides:
# - MCP server for terminal automation (tmux_* tools)
#
# For AI CLI orchestration, use PAL MCP's clink tool.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Resource directories
  resourcesDir = ./resources/claude-code;
  scriptsDir = "${resourcesDir}/scripts";
  skillsDir = "${resourcesDir}/skills";
in
{
  #############################################################################
  # Orchestrator Files
  #############################################################################

  home.file = {
    # Orchestrator MCP server - terminal automation
    ".config/orchestrator-mcp/server.py" = {
      source = "${scriptsDir}/orchestrator-mcp-server.py";
      executable = true;
    };

    # Skills for Claude Code
    ".claude/skills/automating-tmux-windows/SKILL.md".source =
      "${skillsDir}/automating-tmux-windows.md";
    ".claude/skills/ai-orchestration/SKILL.md".source = "${skillsDir}/ai-orchestration.md";
  };
}
