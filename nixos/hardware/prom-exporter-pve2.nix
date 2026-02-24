# Hardware configuration for prom-exporter-pve2 LXC
# Proxmox LXC container running Prometheus exporters on pve2
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/prom-exporter.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "prom-exporter-pve2";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
