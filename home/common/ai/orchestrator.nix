# Orchestrator MCP Server configuration
#
# Provides:
# - MCP server for terminal automation and AI CLI orchestration (claude, codex, gemini)
# - Task management system for multi-agent workflows
#
# AI CLI jobs run directly in tmux windows. Task-bound jobs report results
# via MCP tools (task_comment, task_*_vote). No output parsing is done.
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
    # Orchestrator MCP server - terminal automation + AI CLI orchestration
    ".config/orchestrator-mcp/server.py" = {
      source = "${scriptsDir}/orchestrator-mcp-server.py";
      executable = true;
    };

    # Skills for Claude Code
    ".claude/skills/automating-tmux-windows/SKILL.md".source =
      "${skillsDir}/automating-tmux-windows.md";
    ".claude/skills/ai-orchestration/SKILL.md".source = "${skillsDir}/ai-orchestration.md";
    ".claude/skills/task-add/SKILL.md".source = "${skillsDir}/task-add.md";
  };
}
