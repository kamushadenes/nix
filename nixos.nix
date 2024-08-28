{
  pkgs,
  platform,
  hardware,
  ...
}:
{
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
}
