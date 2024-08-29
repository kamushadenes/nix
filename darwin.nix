{ pkgs, platform, ... }:
let
  packages = import ./packages.nix { inherit pkgs; };
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
    ./darwin/capslock.nix
    ./darwin/db.nix
    ./darwin/dev.nix
    ./darwin/dock.nix
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
    ./darwin/users.nix
    ./darwin/utils.nix
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
  system.stateVersion = 4;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = platform;

  # Timezone
  time.timeZone = "America/Sao_Paulo";
}
