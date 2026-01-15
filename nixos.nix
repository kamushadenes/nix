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
  packages = import ./shared/packages.nix { inherit pkgs; lib = pkgs.lib; };
  overlays = import ./shared/overlays.nix;

  # Check if this is a headless server (no GUI)
  isHeadless = role == "headless";
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
      ./nixos/dev.nix
      ./nixos/fonts.nix
      "${private}/nixos/network.nix"
      ./nixos/nix.nix
      ./nixos/security.nix
      ./nixos/shells.nix
      ./nixos/users.nix
    ]
    # GUI/desktop modules (skip for headless servers)
    ++ lib.optionals (!isHeadless) [
      ./nixos/audio.nix
      ./nixos/browser.nix
      ./nixos/display_gnome.nix
      ./nixos/display_sway.nix
      ./nixos/finance.nix
      ./nixos/ipfs.nix
      ./nixos/media.nix
      ./nixos/meeting.nix
      ./nixos/utils.nix
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

  nixpkgs.overlays = [ overlays.lixOverlay ];

  nix.package = pkgs.lixPackageSets.stable.lix;
}
