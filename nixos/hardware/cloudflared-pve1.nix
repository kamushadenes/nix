# Hardware configuration for cloudflared-pve1 LXC
# Proxmox LXC container running Cloudflare Tunnel on pve1
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/cloudflared.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "cloudflared-pve1";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
