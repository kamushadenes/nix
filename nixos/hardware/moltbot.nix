# Hardware configuration for moltbot LXC
# Proxmox LXC container running moltbot-gateway (Telegram AI assistant)
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/moltbot.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "moltbot";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
