{
  config,
  lib,
  pkgs,
  platform,
  ...
}:
let
  packages = import ./shared/packages.nix { inherit lib pkgs; };
in
{
  _module.args = {
    inherit packages;
  };

  imports = [
    ./shared/cachix.nix

    ./darwin/backup.nix
    ./darwin/brew.nix
    ./darwin/browser.nix
    ./darwin/db.nix
    ./darwin/dev.nix
    ./darwin/dock.nix
    ./darwin/dropbox.nix
    ./darwin/finance.nix
    ./darwin/fonts.nix
    ./darwin/imaging.nix
    ./darwin/ipfs.nix
    ./darwin/login.nix
    ./darwin/mas.nix
    ./darwin/media.nix
    ./darwin/meeting.nix
    ./darwin/network.nix
    ./darwin/nix.nix
    ./darwin/security.nix
    ./darwin/settings.nix
    ./darwin/setapp.nix
    ./darwin/sharing.nix
    ./darwin/shells.nix
    ./darwin/tiling.nix
    ./darwin/users.nix
    ./darwin/utils.nix

    ./darwin/activation.nix
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
  # $ darwin-rebuild changelog
  system.stateVersion = 5;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = platform;

  # Timezone
  time.timeZone = "America/Sao_Paulo";

  age.identityPaths = [ "${config.users.users.kamushadenes.home}/.age/age.pem" ];

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
      "https://nix-community.cachix.org"
      "https://cache.nixos.org"
    ];
    trusted-users = [
      "kamushadenes"
    ];
  };
}
