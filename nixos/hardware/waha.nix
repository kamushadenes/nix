# Hardware configuration for waha LXC
# Proxmox LXC container running WAHA WhatsApp HTTP API
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/waha.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "waha";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
