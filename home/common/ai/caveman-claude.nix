# Caveman mode for Claude Code
#
# Deploys caveman hooks (SessionStart activation, UserPromptSubmit mode tracking)
# to ~/.claude/hooks/caveman/. Skills are deployed via orchestrator.nix.
# Commands are auto-discovered from resources/claude-code/commands/.
{
  config,
  lib,
  ...
}:
let
  cavemanDir = ./resources/claude-code/caveman;
in
{
  home.file = {
    # Hook files — deployed to ~/.claude/hooks/caveman/ as a self-contained unit
    ".claude/hooks/caveman/package.json".source = "${cavemanDir}/package.json";
    ".claude/hooks/caveman/caveman-config.js".source = "${cavemanDir}/caveman-config.js";
    ".claude/hooks/caveman/caveman-activate.js".source = "${cavemanDir}/caveman-activate.js";
    ".claude/hooks/caveman/caveman-mode-tracker.js".source = "${cavemanDir}/caveman-mode-tracker.js";
    ".claude/hooks/caveman/caveman-statusline.sh" = {
      source = "${cavemanDir}/caveman-statusline.sh";
      executable = true;
    };
  };
}
