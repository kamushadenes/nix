{
  pkgs,
  lib,
  platform,
  hardware,
  private,
  role,
  inputs,
  ...
}:
let
  packages = import ./shared/packages.nix { inherit pkgs; lib = pkgs.lib; };
  overlays = import ./shared/overlays.nix;

  # Role-based conditionals
  isHeadless = role == "headless";
  isMinimal = role == "minimal";
  isServer = isHeadless || isMinimal; # Both headless and minimal are "server" roles
in
{
  _module.args = {
    inherit packages;
  };

  imports =
    [
      hardware

      ./shared/build.nix
      ./shared/cache.nix

      # Core modules (always imported)
      "${private}/nixos/network.nix"
      ./nixos/nix.nix
      ./nixos/security.nix
      ./nixos/shells.nix
      ./nixos/users.nix
    ]
    # Development tools (workstation only - not for headless or minimal)
    ++ lib.optionals (!isServer) [
      ./nixos/dev.nix
      ./nixos/fonts.nix
    ]
    # GUI/desktop modules (skip for headless and minimal servers)
    ++ lib.optionals (!isServer) [
      ./nixos/audio.nix
      ./nixos/browser.nix
      ./nixos/display_gnome.nix
      ./nixos/display_sway.nix
      ./nixos/finance.nix
      ./nixos/ipfs.nix
      ./nixos/media.nix
      ./nixos/meeting.nix
      ./nixos/utils.nix
    ]
    # Minimal role specific - default SSH keys
    ++ lib.optionals isMinimal [
      ./nixos/minimal.nix
    ];

  # Allow unfree packages to be installed.
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    git
    gettext
    vim
    readline
    xz
  ];

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Used for backwards compatibility, please read the changelog before changing.
  system.stateVersion = "24.05";

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = platform;

  # Timezone
  time.timeZone = "America/Sao_Paulo";

  nixpkgs.overlays = [
    overlays.lixOverlay
    inputs.nix-moltbot.overlays.default
    inputs.bun2nix.overlays.default
  ];

  nix.package = pkgs.lixPackageSets.stable.lix;
}
