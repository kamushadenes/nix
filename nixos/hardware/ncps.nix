# Hardware configuration for ncps LXC
# Proxmox LXC container running Nix Cache Proxy Server
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/ncps.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "ncps";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
