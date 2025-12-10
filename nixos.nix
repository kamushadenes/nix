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

    ./shared/cachix.nix

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

  nix.settings = {
    connect-timeout = 5;
    fallback = false;
    substituters = [
      "http://ncps.hyades.io:8501"
      "https://nix-community.cachix.org"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "ncps.hyades.io:/02vviGNLGYhW28GFzmPFupnP6gZ4uDD4G3kRnXuutE="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    trusted-substituters = [
      "http://ncps.hyades.io:8501"
    ];
    trusted-users = [
      "kamushadenes"
    ];
  };
}
