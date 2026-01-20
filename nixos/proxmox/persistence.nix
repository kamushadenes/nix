# Configurable persistence for Proxmox guests with ephemeral root
# Provides bind mounts from /nix/persist for state that survives reboots
{ config, lib, ... }:

let
  cfg = config.proxmox.persistence;

  # Always persisted (required for system operation)
  basePaths = [
    "/etc/nixos"
    "/etc/ssh"
    "/var/log"
    "/home"
  ];

  # Combine base + host-specific paths
  allPaths = basePaths ++ cfg.extraPaths;
in
{
  options.proxmox.persistence = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable persistence bind mounts from /nix/persist";
    };

    extraPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional paths to persist across reboots";
      example = [ "/var/lib/postgresql" "/var/lib/docker" ];
    };
  };

  config = lib.mkIf cfg.enable {
    # Generate fileSystems entries for all paths
    fileSystems = lib.listToAttrs (map
      (path: {
        name = path;
        value = {
          device = "/nix/persist${path}";
          fsType = "none";
          options = [ "bind" ];
          neededForBoot = path == "/home";
        };
      })
      allPaths);

    # Create directories on first boot
    system.activationScripts.createPersistDirs = lib.stringAfter [ "var" ] ''
      ${lib.concatMapStringsSep "\n" (p: "mkdir -p /nix/persist${p}") allPaths}
    '';

    # Ensure machine-id persists (needed for systemd-journald)
    environment.etc."machine-id".source = "/nix/persist/etc/machine-id";
  };
}
