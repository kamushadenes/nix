# Peon-Ping — voice notifications for AI coding agents
#
# Uses LCARS (Star Trek TNG) sound pack for session start and stop events.
# Sound packs from the registry are installed via activation script.
{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
{
  home.packages = [ inputs.peon-ping.packages.${pkgs.stdenv.hostPlatform.system}.default ];

  programs.peon-ping = {
    enable = true;
    package = inputs.peon-ping.packages.${pkgs.stdenv.hostPlatform.system}.default;

    installPacks = [ "peon" ];

    settings = {
      default_pack = "lcars";
      volume = 0.5;
      enabled = true;
      desktop_notifications = true;
      categories = {
        "session.start" = true;
        "task.complete" = true;
        "task.error" = false;
        "input.required" = true;
        "resource.limit" = false;
        "user.spam" = false;
        "task.acknowledge" = false;
      };
    };
  };

  # Clean up real packs directory before home-manager links (it was replaced from symlink
  # by peonPingRegistryPacks below, so home-manager would fail on next rebuild)
  home.activation.peonPingCleanPacks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    PACKS_DIR="${config.home.homeDirectory}/.openpeon/packs"
    if [ -d "$PACKS_DIR" ] && ! [ -L "$PACKS_DIR" ]; then
      run rm -rf "$PACKS_DIR"
    fi
  '';

  # Replace nix store packs symlink with a real directory so registry packs can be installed
  home.activation.peonPingRegistryPacks = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    PACKS_DIR="${config.home.homeDirectory}/.openpeon/packs"
    if [ -L "$PACKS_DIR" ]; then
      # Copy nix-managed packs to a real directory
      STORE_TARGET="$(readlink "$PACKS_DIR")"
      run rm "$PACKS_DIR"
      run cp -rL "$STORE_TARGET" "$PACKS_DIR"
      run chmod -R u+w "$PACKS_DIR"
    fi
    if ! [ -d "$PACKS_DIR/lcars" ]; then
      run ${lib.getExe inputs.peon-ping.packages.${pkgs.stdenv.hostPlatform.system}.default} packs install lcars || true
    fi
  '';
}
