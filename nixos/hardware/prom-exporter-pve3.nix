# Hardware configuration for prom-exporter-pve3 LXC
# Proxmox LXC container running Prometheus exporters on pve3
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

  networking.hostName = "prom-exporter-pve3";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
