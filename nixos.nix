{
  pkgs,
  platform,
  hardware,
  ...
}:
let
  packages = import ./shared/packages.nix { inherit pkgs; };
in
{
  _module.args = {
    inherit packages;
  };

  imports = [
    hardware

    ./shared/build.nix
    ./shared/cache.nix

    ./nixos/audio.nix
    ./nixos/browser.nix
    ./nixos/display_gnome.nix
    ./nixos/display_sway.nix
    ./nixos/dev.nix
    ./nixos/finance.nix
    ./nixos/fonts.nix
    ./nixos/ipfs.nix
    ./nixos/media.nix
    ./nixos/meeting.nix
    ./nixos/network.nix
    ./nixos/nix.nix
    ./nixos/security.nix
    ./nixos/shells.nix
    ./nixos/users.nix
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

  nixpkgs.overlays = [
    (final: prev: {
      inherit (prev.lixPackageSets.stable)
        nixpkgs-review
        nix-eval-jobs
        nix-fast-build
        colmena
        ;
    })
  ];

  nix.package = pkgs.lixPackageSets.stable.lix;
}
