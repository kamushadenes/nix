# Hardware configuration for prometheus LXC
# Proxmox LXC container running Prometheus server on pve1
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/prometheus.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "prometheus";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
