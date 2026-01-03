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
    ".claude/skills/verification-loops/SKILL.md".source = "${skillsDir}/verification-loops.md";
    ".claude/skills/feedback-loop/SKILL.md".source = "${skillsDir}/feedback-loop.md";
    ".claude/skills/parallel-processing/SKILL.md".source = "${skillsDir}/parallel-processing.md";

    # Language and framework skills
    ".claude/skills/golang-pro/SKILL.md".source = "${skillsDir}/golang-pro/SKILL.md";
    ".claude/skills/golang-pro/references/concurrency.md".source = "${skillsDir}/golang-pro/references/concurrency.md";
    ".claude/skills/golang-pro/references/testing.md".source = "${skillsDir}/golang-pro/references/testing.md";
    ".claude/skills/golang-pro/references/project-structure.md".source = "${skillsDir}/golang-pro/references/project-structure.md";

    ".claude/skills/python-pro/SKILL.md".source = "${skillsDir}/python-pro/SKILL.md";
    ".claude/skills/typescript-pro/SKILL.md".source = "${skillsDir}/typescript-pro/SKILL.md";
    ".claude/skills/sql-pro/SKILL.md".source = "${skillsDir}/sql-pro/SKILL.md";
    ".claude/skills/rust-engineer/SKILL.md".source = "${skillsDir}/rust-engineer/SKILL.md";

    # Spec mining and infrastructure skills
    ".claude/skills/spec-miner/SKILL.md".source = "${skillsDir}/spec-miner/SKILL.md";
    ".claude/skills/terraform-engineer/SKILL.md".source = "${skillsDir}/terraform-engineer/SKILL.md";
    ".claude/skills/terraform-engineer/references/module-patterns.md".source = "${skillsDir}/terraform-engineer/references/module-patterns.md";
    ".claude/skills/terraform-engineer/references/state-management.md".source = "${skillsDir}/terraform-engineer/references/state-management.md";
  };
}
