# Configurable persistence for Proxmox guests with ephemeral root
# Provides bind mounts from /nix/persist for state that survives reboots
{ config, lib, pkgs, ... }:

let
  cfg = config.proxmox.persistence;

  # Always persisted (required for system operation)
  # Note: /etc/ssh is NOT bind mounted - we persist host keys via services.openssh.hostKeys
  basePaths = [
    "/etc/nixos"
    "/var/log"
    "/home"
  ];

  # Combine base + host-specific paths
  allPaths = basePaths ++ cfg.extraPaths;

  # Script to create all persist directories and generate required files
  createPersistDirsScript = pkgs.writeShellScript "create-persist-dirs" ''
    # Create all persist directories
    ${lib.concatMapStringsSep "\n" (p: "mkdir -p /nix/persist${p}") allPaths}

    # Ensure machine-id exists (generate if missing)
    if [ ! -f /nix/persist/etc/machine-id ]; then
      mkdir -p /nix/persist/etc
      ${pkgs.systemd}/bin/systemd-machine-id-setup --root=/nix/persist
    fi

    # Generate SSH host keys if missing (required for sshd to start)
    if [ ! -f /nix/persist/etc/ssh/ssh_host_ed25519_key ]; then
      ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f /nix/persist/etc/ssh/ssh_host_ed25519_key -N ""
    fi
    if [ ! -f /nix/persist/etc/ssh/ssh_host_rsa_key ]; then
      ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -f /nix/persist/etc/ssh/ssh_host_rsa_key -N ""
    fi
  '';
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
    # Create persist directories BEFORE filesystem mounts
    # This service runs very early, before local-fs-pre.target
    systemd.services.create-persist-dirs = {
      description = "Create persistence directories";
      wantedBy = [ "local-fs-pre.target" ];
      before = [ "local-fs-pre.target" ];
      unitConfig = {
        DefaultDependencies = "no";
        # Only run if /nix exists (should always be true on NixOS)
        ConditionPathExists = "/nix";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = createPersistDirsScript;
      };
    };

    # Generate fileSystems entries for all paths
    # These mounts depend on create-persist-dirs completing first
    fileSystems = lib.listToAttrs (map
      (path: {
        name = path;
        value = {
          device = "/nix/persist${path}";
          fsType = "none";
          options = [
            "bind"
            "x-systemd.requires=create-persist-dirs.service"
          ];
          neededForBoot = path == "/home";
        };
      })
      allPaths);

    # Ensure machine-id persists (needed for systemd-journald)
    environment.etc."machine-id".source = "/nix/persist/etc/machine-id";
  };
}
