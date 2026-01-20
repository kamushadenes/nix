{
  config,
  inputs,
  pkgs,
  pkgs-unstable,
  lib,
  osConfig,
  private,
  role ? "workstation",
  platform ? "darwin",
  ...
}:
let
  fishPlugins = import ./shared/fish-plugins.nix { inherit pkgs; };
  helpers = import ./shared/helpers.nix { inherit config lib pkgs osConfig; };
  packages = import ./shared/packages.nix { inherit lib pkgs; };
  shellCommon = import ./shared/shell-common.nix { inherit config lib pkgs osConfig private packages; };
  themes = import ./shared/themes.nix { inherit pkgs; };

  # Role-based module composition
  roles = import ./shared/roles.nix { inherit lib private; };
  roleModules = roles.mkRoleModules { inherit role platform; };
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
    # Agenix home-manager module (always needed)
    inputs.agenix.homeManagerModules.default
  ] ++ roleModules;

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
          ${fish} "_evalcache_clear" || true
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
