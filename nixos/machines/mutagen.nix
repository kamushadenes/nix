# Machine configuration for mutagen LXC
# Mutagen sync hub — direct NFS mount (privileged container)
{ config, lib, pkgs, private, ... }:

{
  imports = [ "${private}/nixos/lxc-management.nix" ];
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  boot.supportedFilesystems = [ "nfs" ];

  fileSystems."/home/kamushadenes/Dropbox" = {
    device = "10.23.23.14:/mnt/HDD/Dropbox";
    fsType = "nfs";
    options = [ "defaults" "_netdev" "x-systemd.automount" ];
  };

  # Path compatibility for Darwin-style paths
  systemd.tmpfiles.rules = [
    "L /Users - - - - /home"
  ];

  networking.networkmanager.enable = lib.mkForce false;
}
