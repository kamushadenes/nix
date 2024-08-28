{
  config,
  inputs,
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  opBinPath = "${pkgs._1password}/bin/op";

  globalVariables = {
    base = {
      DOOMDIR = "${config.xdg.configHome}/doom";
      EMACSDIR = "${config.xdg.configHome}/emacs";
      DOOMLOCALDIR = "${config.xdg.dataHome}/doom";
      DOOMPROFILELOADFILE = "${config.xdg.stateHome}/doom-profiles-load.el";

      NIX_HM_PROFILE = config.home.profileDirectory;

      OP_BIN_PATH = opBinPath;

      FLAKE = "${config.home.homeDirectory}/.config/nix/config/?submodules=1";
    };

    launchctl = lib.concatMapStringsSep "\n" (var: ''
      run /bin/launchctl setenv ${var} "${globalVariables.base.${var}}"
    '') (lib.attrNames globalVariables.base);

    shell = lib.concatMapStringsSep "\n" (var: ''
      export ${var}="${globalVariables.base.${var}}"
    '') (lib.attrNames globalVariables.base);

    fishShell = lib.concatMapStringsSep "\n" (var: ''
      set -x ${var} "${globalVariables.base.${var}}"
    '') (lib.attrNames globalVariables.base);
  };

  fromYAML =
    yaml:
    builtins.fromJSON (
      builtins.readFile (
        pkgs.runCommand "from-yaml"
          {
            inherit yaml;
            allowSubstitutes = false;
            preferLocalBuild = true;
          }
          ''
            ${pkgs.remarshal}/bin/remarshal  \
              -if yaml \
              -i <(echo "$yaml") \
              -of json \
              -o $out
          ''
      )
    );

  readYAML = path: fromYAML (builtins.readFile path);
in
{
  nixpkgs.config.allowUnfree = true;

  _module.args = {
    inherit
      globalVariables
      opBinPath
      fromYAML
      readYAML
      ;
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
    ./home/common/editors/editor.nix
    ./home/common/editors/emacs.nix
    ./home/common/editors/vim.nix

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
      inherit (pkgs.stdenv) isLinux isDarwin;

      fish = ''run ${pkgs.fish}/bin/fish -c'';
    in
    lib.mkMerge [
      # Common
      {
        doom = lib.hm.dag.entryAfter [ "doomEnv" ] ''
          ${fish} "${config.xdg.configHome}/emacs/bin/doom sync"
        '';
      }

      # Linux
      (lib.mkIf (isLinux) { doomEnv = lib.hm.dag.entryAfter [ "installPackages" ] ''''; })

      # Darwin
      (lib.mkIf (isDarwin) {
        doomEnv = lib.hm.dag.entryAfter [ "installPackages" ] globalVariables.launchctl;
      })
    ];

  age.identityPaths = [ "${config.home.homeDirectory}/.age/age.pem" ];
}
