# Hardware configuration for haos LXC
# Proxmox LXC container running Home Assistant (native NixOS service)
# Dual NIC: eth0 on VLAN 3 (IoT), eth1 on VLAN 6 (Infra)
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/haos.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "haos";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
