# Hardware configuration for influxdb LXC
# Proxmox LXC container running InfluxDB v2 on pve1
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/influxdb.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "influxdb";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
