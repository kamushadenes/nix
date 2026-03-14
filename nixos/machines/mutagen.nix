# Machine configuration for mutagen LXC
# Mutagen sync hub — NFS via PVE bind mount (mp0), symlink at /home/kamushadenes/Dropbox
{ config, lib, pkgs, private, ... }:

{
  imports = [ "${private}/nixos/lxc-management.nix" ];
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # NFS is mounted on the PVE host (/mnt/dropbox) and bind-mounted into the container
  # at /mnt/dropbox via pct mp0. NFS doesn't work natively in unprivileged LXC containers.
  # Symlink /home/kamushadenes/Dropbox -> /mnt/dropbox for path compatibility.
  systemd.tmpfiles.rules = [
    "L /Users - - - - /home"
    "L+ /home/kamushadenes/Dropbox - - - - /mnt/dropbox"
  ];

  networking.networkmanager.enable = lib.mkForce false;
}
