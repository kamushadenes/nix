# Hardware configuration for media LXC
# Privileged Proxmox LXC running the *arr stack, downloaders, Jellyfin,
# Zilean+Postgres, Profilarr, and Caddy reverse proxy.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/media.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "media";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
