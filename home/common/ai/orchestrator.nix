# Orchestrator MCP Server and CLI configuration
#
# Provides:
# - orchestrator CLI for managing AI jobs from outside tmux
# - MCP server for terminal automation and AI CLI orchestration (claude, codex, gemini)
# - TUI runner for real-time job monitoring with JSON parsing
#
# The orchestrator runs AI CLI jobs in tmux windows for visibility,
# parses their JSON output, and provides a TUI with sticky header and scrollable output.
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

  # Python with required dependencies for TUI
  pythonWithDeps = pkgs.python3.withPackages (ps: [
    ps.textual # TUI framework
    ps.rich # Rich text formatting
  ]);

  # Orchestrator CLI - wrapper that invokes the Python script with proper dependencies
  orchestratorCli = pkgs.writeShellScriptBin "orchestrator" ''
    ${pythonWithDeps}/bin/python3 ${config.home.homeDirectory}/.config/orchestrator-mcp/cli.py "$@"
  '';
in
{
  #############################################################################
  # Orchestrator CLI Package
  #############################################################################

  home.packages = [
    orchestratorCli
  ];

  #############################################################################
  # Orchestrator Files
  #############################################################################

  home.file = {
    # Orchestrator MCP server - terminal automation + AI CLI orchestration
    ".config/orchestrator-mcp/server.py" = {
      source = "${scriptsDir}/orchestrator-mcp-server.py";
      executable = true;
    };

    # Orchestrator CLI - for external monitoring and TUI runner
    ".config/orchestrator-mcp/cli.py" = {
      source = "${scriptsDir}/orchestrator-cli.py";
      executable = true;
    };

    # Skills for Claude Code
    ".claude/skills/automating-tmux-windows/SKILL.md".source =
      "${skillsDir}/automating-tmux-windows.md";
    ".claude/skills/ai-orchestration/SKILL.md".source = "${skillsDir}/ai-orchestration.md";
  };
}
