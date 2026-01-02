{
  config,
  inputs,
  pkgs,
  pkgs-unstable,
  lib,
  osConfig,
  private,
  ...
}:
let
  fishPlugins = import ./shared/fish-plugins.nix { inherit pkgs; };
  helpers = import ./shared/helpers.nix { inherit config lib pkgs osConfig; };
  packages = import ./shared/packages.nix { inherit lib pkgs; };
  shellCommon = import ./shared/shell-common.nix { inherit config lib pkgs osConfig; };
  themes = import ./shared/themes.nix { inherit pkgs; };
in
{
  _module.args = {
    inherit helpers;
    inherit packages;
    inherit shellCommon;
    inherit themes;
    inherit fishPlugins;
    inherit pkgs-unstable;
  };

  imports = [
    # Core
    inputs.agenix.homeManagerModules.default
    ./home/common/core/agenix.nix
    ./home/common/core/fonts.nix
    ./home/common/core/git.nix
    ./home/common/core/network.nix
    ./home/common/core/nix.nix
    "${private}/home/common/core/ssh.nix"

    # Shell
    ./home/common/shell/bash.nix
    ./home/common/shell/fish.nix
    ./home/common/shell/zsh.nix
    ./home/common/shell/ghostty.nix
    ./home/common/shell/kitty.nix
    ./home/common/shell/misc.nix
    ./home/common/shell/starship.nix
    ./home/common/shell/tmux.nix

    # Development
    ./home/common/dev/android.nix
    ./home/common/dev/clang.nix
    ./home/common/dev/claude-code.nix
    ./home/common/dev/clojure.nix
    ./home/common/dev/codex-cli.nix
    ./home/common/dev/dev.nix
    ./home/common/dev/embedded.nix
    ./home/common/dev/gemini-cli.nix
    ./home/common/dev/go.nix
    ./home/common/dev/java.nix
    ./home/common/dev/lazygit.nix
    ./home/common/dev/node.nix
    ./home/common/dev/python.nix

    # Editors
    ./home/common/editors/emacs.nix
    ./home/common/editors/nvim.nix

    # Infra
    ./home/common/infra/cloud.nix
    ./home/common/infra/db.nix
    ./home/common/infra/docker.nix
    ./home/common/infra/iac.nix
    ./home/common/infra/kubernetes.nix

    # Media
    ./home/common/media/media.nix

    # Security
    ./home/common/security/gpg.nix
    ./home/common/security/tools.nix

    # Utils
    ./home/common/utils/aichat.nix
    ./home/common/utils/utils.nix

    # Altinity
    "${private}/home/altinity/clickhouse.nix"
    "${private}/home/altinity/cloud.nix"
    "${private}/home/altinity/utils.nix"

    # MacOS specific
    ./home/macos/aerospace.nix
    ./home/macos/bettertouchtool.nix
    ./home/macos/sketchybar.nix

    # Linux specific
    ./home/linux/display.nix
    ./home/linux/security.nix
    ./home/linux/shell.nix
    ./home/linux/systemd.nix
  ];

  home.stateVersion = "24.05";
  programs.home-manager.enable = true;

  home.activation =
    let
      fish = ''run ${lib.getExe pkgs.fish} -c'';
    in
    lib.mkMerge [
      # Common
      {
        evalcacheClear = lib.hm.dag.entryAfter [ "installPackages" ] ''
          ${fish} "_evalcache_clear"
        '';

        doom = lib.hm.dag.entryAfter [ "doomEnv" ] (
          if config.programs.emacs.enable then
            ''
              ${fish} "${config.xdg.configHome}/emacs/bin/doom sync"
            ''
          else
            ''''
        );
      }

      # Linux
      (lib.mkIf pkgs.stdenv.isLinux { doomEnv = lib.hm.dag.entryAfter [ "evalcacheClear" ] ''''; })

      # Darwin
      (lib.mkIf pkgs.stdenv.isDarwin {
        doomEnv = lib.hm.dag.entryAfter [ "evalcacheClear" ] helpers.globalVariables.launchctl;

        betterTouchToolRestart = lib.hm.dag.entryAfter [ "evalcacheClear" ] ''
          ${fish} "osascript -e 'quit app \"BetterTouchTool\"'"
          ${fish} "defaults write com.hegenberg.BetterTouchTool BTTAutoLoadPath ${config.xdg.configHome}/bettertouchtool/default_preset.json"
          ${fish} "open -a BetterTouchTool"
        '';
      })
    ];

  age.identityPaths = [ "${config.home.homeDirectory}/.age/age.pem" ];
}
