# Home-manager configuration for root user on NixOS
# Provides the same shell environment as kamushadenes (role-based)
{
  config,
  inputs,
  pkgs,
  pkgs-unstable,
  lib,
  osConfig,
  private,
  role ? "minimal",
  platform ? "x86_64-linux",
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

  imports = roleModules;

  home.stateVersion = "25.11";
  home.username = lib.mkForce "root";
  home.homeDirectory = lib.mkForce "/root";

  programs.home-manager.enable = true;
}
