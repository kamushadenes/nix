# Hardware configuration for aether.hyades.io
# This is a placeholder - replace with output from nixos-generate-config
# when the actual machine is provisioned.
#
# To generate on the machine:
#   nixos-generate-config --show-hardware-config > hardware-configuration.nix
#
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  # TODO: Replace these imports with appropriate hardware modules for your cloud provider
  # Common options:
  #   - AWS EC2: (modulesPath + "/virtualisation/amazon-image.nix")
  #   - GCP: (modulesPath + "/virtualisation/google-compute-image.nix")
  #   - Azure: (modulesPath + "/virtualisation/azure-image.nix")
  #   - Generic VM/QEMU: (modulesPath + "/profiles/qemu-guest.nix")
  #   - Bare metal: Use nixos-generate-config output
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  services.qemuGuest.enable = true;

  # Bootloader - adjust based on your setup (UEFI vs BIOS)
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda"; # or /dev/vda for virtio

  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "virtio_pci"
    "virtio_scsi"
    "sr_mod"
    "virtio_blk"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # TODO: Replace with actual disk UUID from blkid
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/PLACEHOLDER-REPLACE-WITH-ACTUAL-UUID";
    fsType = "ext4";
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
