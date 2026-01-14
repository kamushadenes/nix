{
  config,
  lib,
  pkgs,
  platform,
  private,
  ...
}:
let
  packages = import ./shared/packages.nix { inherit lib pkgs; };
  overlays = import ./shared/overlays.nix;
in
{
  _module.args = {
    inherit packages;
  };

  imports = [
    ./shared/build.nix
    ./shared/cache.nix

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
    "${private}/darwin/network.nix"
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

  # Linux builder VM for cross-platform builds (e.g., rebuild aether from macOS)
  # The VM runs aarch64-linux natively and emulates x86_64-linux via binfmt/qemu
  nix.linux-builder = {
    enable = true;
    systems = [ "x86_64-linux" "aarch64-linux" ];
    maxJobs = 4;
    config = { lib, ... }: {
      # Enable binfmt emulation for x86_64-linux on the aarch64-linux VM
      boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
      # Give the VM more resources for building
      virtualisation = {
        cores = lib.mkForce 4;
        memorySize = lib.mkForce 8192; # 8GB RAM
        diskSize = lib.mkForce 40960; # 40GB disk
      };
    };
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = platform;

  # Timezone
  time.timeZone = "America/Sao_Paulo";

  age.identityPaths = [ "${config.users.users.kamushadenes.home}/.age/age.pem" ];

  nixpkgs.overlays = [ overlays.lixOverlay ];

  nix.package = pkgs.lixPackageSets.stable.lix;
}
