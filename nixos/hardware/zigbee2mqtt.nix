# Hardware configuration for zigbee2mqtt LXC
# Proxmox LXC container running Zigbee2MQTT with USB passthrough
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/zigbee2mqtt.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "zigbee2mqtt";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
