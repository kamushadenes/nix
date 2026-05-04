# Hardware configuration for stremio LXC
# Proxmox LXC container running Stremio Server
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/stremio.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "stremio";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
