# Hardware configuration for stremthru LXC
# Unprivileged Proxmox LXC running StremThru (Stremio addon proxy / RD bridge)
# behind Caddy with Let's Encrypt + Cloudflare DNS-01.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/stremthru.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "stremthru";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
