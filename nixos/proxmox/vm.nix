# Proxmox VMA image configuration
# Produces a .vma.zst file that can be restored in Proxmox as a VM
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./common.nix
  ];

  # VM disk size (10GB default, override in nixosConfigurations)
  # Set with mkForce to override proxmox module's deprecated qemuConf.diskSize default
  virtualisation.diskSize = lib.mkForce 10240;

  # QEMU guest agent for Proxmox integration
  services.qemuGuest.enable = true;

  # Boot configuration for Proxmox VMs
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  # Kernel modules for virtio
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
    "ahci"
    "sd_mod"
  ];

  # Filesystem layout:
  # - tmpfs root (ephemeral, 2GB for base image)
  # - ext4 on /dev/disk/by-label/nix for /nix
  # Note: mkForce needed to override defaults from proxmox-image.nix
  fileSystems."/" = {
    device = lib.mkForce "none";
    fsType = lib.mkForce "tmpfs";
    autoResize = lib.mkForce false;
    options = lib.mkForce [
      "defaults"
      "size=2G"
      "mode=0755"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/nix";
    fsType = "ext4";
    neededForBoot = true;
  };

  # Default hostname (should be overridden when adding to nixosConfigurations)
  networking.hostName = lib.mkDefault "nixos-proxmox";

  # Platform
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
