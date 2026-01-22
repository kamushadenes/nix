# Hardware configuration for mqtt LXC
# Proxmox LXC container running Mosquitto MQTT broker
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/mqtt.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "mqtt";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
