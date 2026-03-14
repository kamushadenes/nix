# Hardware configuration for mutagen LXC
# Proxmox LXC container - Mutagen sync hub with NFS-mounted TrueNAS Dropbox
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/mutagen.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "mutagen";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
