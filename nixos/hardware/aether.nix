# Hardware configuration for aether.hyades.io
# Hetzner dedicated server with RAID1 boot and LUKS-encrypted root
#
# This file contains hardware-specific settings only.
# Network configuration and sensitive settings are in private/nixos/aether.nix
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Initrd kernel modules for hardware support
  boot.initrd.availableKernelModules = [
    "ahci" # SATA/AHCI controller
    "sd_mod" # SCSI disk support
    "nvme" # NVMe storage
    "aesni_intel" # Hardware AES acceleration for LUKS
    "cryptd" # Crypto daemon for async encryption
    "igb" # Intel Gigabit Ethernet (for initrd networking)
    "e1000e" # Intel PRO/1000 Ethernet
  ];
  boot.initrd.kernelModules = [ ];

  # Main system kernel modules
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Enable aarch64-linux emulation via QEMU binfmt
  # Allows building aarch64-linux packages (e.g., for darwin linux-builder bootstrap)
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Filesystem layout:
  # - tmpfs root (ephemeral, 8GB)
  # - Two ext4 boot partitions (mirrored manually)
  # - LUKS-encrypted ext4 on md0 RAID array mounted at /nix

  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [
      "defaults"
      "size=8G"
      "mode=0755"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot0";
    fsType = "ext4";
  };

  fileSystems."/boot-fallback" = {
    device = "/dev/disk/by-label/boot1";
    fsType = "ext4";
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/nix";
    fsType = "ext4";
  };

  # LUKS encryption on software RAID
  boot.initrd.luks.devices."cryptroot".device = "/dev/md0";

  # Bind mounts for persistence (state that survives reboots)
  fileSystems."/etc/nixos" = {
    device = "/nix/persist/etc/nixos";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/var/log" = {
    device = "/nix/persist/var/log";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/home" = {
    device = "/nix/persist/home";
    fsType = "none";
    options = [ "bind" ];
    neededForBoot = true;
  };

  swapDevices = [ ];

  # Platform
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
