# Hardware configuration for esphome LXC
# Proxmox LXC container running ESPHome dashboard
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/esphome.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "esphome";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
