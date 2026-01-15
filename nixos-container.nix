# NixOS configuration for container environments
# Streamlined version of nixos.nix without distributed builds, network secrets,
# or other components that don't make sense in containers
{
  pkgs,
  lib,
  platform,
  hardware,
  private,
  role,
  ...
}:
let
  packages = import ./shared/packages.nix {
    inherit pkgs;
    lib = pkgs.lib;
  };
  overlays = import ./shared/overlays.nix;

  # Containers are always headless
  isContainer = role == "container";
in
{
  _module.args = {
    inherit packages;
  };

  imports = [
    hardware

    # Skip build.nix - containers don't do distributed builds
    # Skip cache.nix - containers use host's cache
    # Skip network.nix from private - containers handle networking via Docker

    # Core modules
    ./nixos/dev.nix
    ./nixos/fonts.nix
    ./nixos/nix.nix
    ./nixos/shells.nix
    ./nixos/users.nix
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    git
    gettext
    vim
    readline
    xz
    # Container-specific utilities
    tini # Better init for containers
  ];

  # Flakes support
  nix.settings.experimental-features = "nix-command flakes";

  # State version
  system.stateVersion = "24.05";

  # Platform
  nixpkgs.hostPlatform = platform;

  # Containers should use UTC
  time.timeZone = "UTC";

  # Lix overlay and package
  nixpkgs.overlays = [ overlays.lixOverlay ];
  nix.package = pkgs.lixPackageSets.stable.lix;

  # Container-specific settings
  services.openssh.enable = lib.mkForce false;
  networking.firewall.enable = lib.mkForce false;

  # Disable udev - not available in containers
  services.udev.enable = lib.mkForce false;

  # Disable services that don't make sense in containers
  systemd.services."systemd-udev-trigger".enable = lib.mkForce false;
  systemd.services."systemd-udevd".enable = lib.mkForce false;
}
