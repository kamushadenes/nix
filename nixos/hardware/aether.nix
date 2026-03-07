# Hardware configuration for aether LXC
# Proxmox LXC container - full dev environment (headless role)
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/virtualisation/proxmox-lxc.nix") ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "aether";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
