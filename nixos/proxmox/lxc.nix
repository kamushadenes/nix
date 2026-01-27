# Proxmox LXC container template configuration
# Produces a .tar.xz file that can be used to create LXC containers in Proxmox
#
# Proxmox settings for NixOS LXC:
# - Unprivileged: Yes
# - Nesting: Enabled (required for nix-daemon)
# - Features: fuse=1,nesting=1
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ./common.nix
  ];

  # LXC-specific boot configuration
  boot.isContainer = true;

  # Console configuration for LXC
  # Proxmox uses /dev/console for container console access
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  # Ensure console-getty is properly configured
  systemd.services.console-getty = {
    serviceConfig = {
      ExecStart = [
        ""  # Clear default
        "${pkgs.util-linux}/sbin/agetty --noclear --keep-baud console 115200,38400,9600 $TERM"
      ];
      Restart = "always";
    };
  };

  # Filesystem layout for LXC:
  # The container root is managed by Proxmox, but we configure
  # persistence paths that should be bind-mounted from the host
  # or persistent storage

  # Default hostname (should be overridden when adding to nixosConfigurations)
  networking.hostName = lib.mkDefault "nixos-lxc";

  # Platform
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # LXC containers don't need bootloader
  boot.loader.grub.enable = false;
}
