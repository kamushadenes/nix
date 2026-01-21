# Minimal home-manager configuration for root user
# Used primarily to provide SSH config for nix remote builds
{
  config,
  lib,
  pkgs,
  private,
  ...
}:
{
  imports = [
    "${private}/home/root/ssh.nix"
  ];

  home.stateVersion = "25.11";
  home.username = lib.mkForce "root";
  home.homeDirectory = lib.mkForce "/var/root";
}
