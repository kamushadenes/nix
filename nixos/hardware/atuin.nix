# Hardware configuration for atuin LXC
# Proxmox LXC container running Atuin shell history sync server
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/atuin.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "atuin";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
