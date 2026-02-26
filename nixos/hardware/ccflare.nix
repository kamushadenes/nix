# Hardware configuration for ccflare LXC
# Proxmox LXC container running ccflare Claude API proxy
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/ccflare.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "ccflare";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
