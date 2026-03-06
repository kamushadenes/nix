# Peon-Ping — Warcraft III voice notifications for AI coding agents
#
# Plays Peon voice lines ("Job's done!", "Work work...") when Claude Code
# needs attention (task complete, error, permission request, etc.)
#
# Sound packs are installed declaratively via the HM module.
# Claude Code hooks are set up by `peon setup claude` after rebuild.
{
  inputs,
  pkgs,
  ...
}:
{
  home.packages = [ inputs.peon-ping.packages.${pkgs.system}.default ];

  programs.peon-ping = {
    enable = true;
    package = inputs.peon-ping.packages.${pkgs.system}.default;

    installPacks = [ "peon" ];

    settings = {
      default_pack = "peon";
      volume = 0.5;
      enabled = true;
      desktop_notifications = true;
      categories = {
        "session.start" = true;
        "task.complete" = true;
        "task.error" = false;
        "input.required" = true;
        "resource.limit" = false;
        "user.spam" = false;
        "task.acknowledge" = false;
      };
    };
  };
}
