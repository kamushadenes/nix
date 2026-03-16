# Machine configuration for aether
# NFS mount for Dropbox storage (TrueNAS) — same share as mutagen LXC
{ config, lib, pkgs, private, ... }:

{
  boot.supportedFilesystems = [ "nfs" ];

  fileSystems."/home/kamushadenes/Dropbox" = {
    device = "10.23.23.14:/mnt/HDD/Dropbox";
    fsType = "nfs";
    options = [ "defaults" "_netdev" ];
  };
}
