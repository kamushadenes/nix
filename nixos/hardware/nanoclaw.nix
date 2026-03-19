# Hardware configuration for nanoclaw LXC
# Proxmox LXC container running NanoClaw (personal AI agent for WhatsApp/Telegram)
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/nanoclaw.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "nanoclaw";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
