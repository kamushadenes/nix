{
  config,
  inputs,
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  fishPlugins = import ./shared/fish-plugins.nix { inherit pkgs; };
  helpers = import ./shared/helpers.nix {
    inherit config;
    inherit lib;
    inherit pkgs;
    inherit osConfig;
  };
  packages = import ./shared/packages.nix { inherit pkgs; };
  themes = import ./shared/themes.nix { inherit pkgs; };
in
{
  nixpkgs.config.allowUnfree = true;

  _module.args = {
    inherit helpers;
    inherit packages;
    inherit themes;
    inherit fishPlugins;
  };

  imports = [
    # Backup
    ./home/common/backup/backup.nix

    # Core
    inputs.agenix.homeManagerModules.default
    ./home/common/core/agenix.nix
    ./home/common/core/fonts.nix
    ./home/common/core/git.nix
    ./home/common/core/network.nix
    ./home/common/core/nix.nix
    ./home/common/core/ssh.nix

    # Shell
    ./home/common/shell/bash.nix
    ./home/common/shell/fish.nix
    ./home/common/shell/kitty.nix
    ./home/common/shell/misc.nix
    ./home/common/shell/starship.nix

    # Development
    ./home/common/dev/android.nix
    ./home/common/dev/clang.nix
    ./home/common/dev/clojure.nix
    ./home/common/dev/dev.nix
    ./home/common/dev/embedded.nix
    ./home/common/dev/go.nix
    ./home/common/dev/java.nix
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
    ./home/common/utils/utils.nix

    # Altinity
    ./home/altinity/clickhouse.nix
    ./home/altinity/cloud.nix
    ./home/altinity/utils.nix

    # MacOS specific
    ./home/macos/aerospace.nix
    ./home/macos/dropbox.nix

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

        doom = lib.hm.dag.entryAfter [ "doomEnv" ] ''
          ${fish} "${config.xdg.configHome}/emacs/bin/doom sync"
        '';
      }

      # Linux
      (lib.mkIf pkgs.stdenv.isLinux { doomEnv = lib.hm.dag.entryAfter [ "evalcacheClear" ] ''''; })

      # Darwin
      (lib.mkIf pkgs.stdenv.isDarwin {
        doomEnv = lib.hm.dag.entryAfter [ "evalcacheClear" ] helpers.globalVariables.launchctl;

        #backrestRestart = lib.hm.dag.entryAfter [ "evalcacheClear" ] ''
        #  ${fish} "test -f /tmp/.restart_backrest; and ${osConfig.homebrew.brewPrefix}/brew services restart backrest; and rm -f /tmp/.restart_backrest"
        #'';
      })
    ];

  age.identityPaths = [ "${config.home.homeDirectory}/.age/age.pem" ];
}
