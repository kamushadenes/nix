# Minimal shell utilities for service containers
# Includes only essential tools to keep closure size small
# For full toolset, see misc.nix (used in workstation/headless roles)
{
  config,
  pkgs,
  pkgs-unstable,
  lib,
  helpers,
  ...
}:
{
  home.packages = [
    pkgs-unstable.nh # Nix helper for rebuild/clean commands
  ];

  programs = {
    ripgrep.enable = true;

    fd = {
      enable = true;
      ignores = [
        ".git/"
        "*.bak"
      ];
    };

    bat = {
      enable = true;
      config.theme = "ansi"; # No theme file dependencies
      # No extraPackages (batdiff, batman, etc.) to minimize closure
    };

    eza = {
      enable = true;
      git = true;
      icons = "auto";
    } // helpers.shellIntegrations;

    fzf = lib.mkMerge [
      ({
        enable = true;
        defaultOptions = [
          "--multi"
          "--border"
        ];
      } // helpers.shellIntegrationsNoFish)
      (lib.mkIf config.programs.fd.enable {
        changeDirWidgetCommand = "${lib.getExe config.programs.fd.package} --type d";
        defaultCommand = "${lib.getExe config.programs.fd.package} --type f";
        fileWidgetCommand = "${lib.getExe config.programs.fd.package} --type f";
      })
    ];

    # Basic utilities
    htop.enable = true;
    jq.enable = true;
    less.enable = true;
  };
}
