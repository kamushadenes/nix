# Hardware configuration for aiostreams LXC
# Proxmox LXC container running AIOStreams (Stremio addon aggregator)
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/aiostreams.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "aiostreams";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
