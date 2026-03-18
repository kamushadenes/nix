# Machine configuration for aether
# NFS mount for Dropbox storage (TrueNAS) — same share as mutagen LXC
# OpenChamber — web UI for OpenCode AI agent (Docker)
{
  config,
  lib,
  pkgs,
  private,
  ...
}:

let
  openchamberVersion = "v1.8.7";
  openchamberImage = "openchamber:${openchamberVersion}";
  openchamberDataDir = "/var/lib/openchamber";
  openchamberPort = 3000;

  homeDir = "/home/kamushadenes";
in
{
  boot.supportedFilesystems = [ "nfs" ];

  fileSystems."/home/kamushadenes/Dropbox" = {
    device = "10.23.23.14:/mnt/HDD/Dropbox";
    fsType = "nfs";
    options = [
      "defaults"
      "_netdev"
    ];
  };

  # --- Docker ---
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # --- OpenChamber: build Docker image from source ---
  systemd.services.openchamber-build = {
    description = "Build OpenChamber Docker image from source";
    after = [
      "docker.service"
      "network-online.target"
    ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "600"; # Docker build can take a while
    };

    path = [
      pkgs.git
      pkgs.docker
      pkgs.coreutils
    ];

    script = ''
      set -euo pipefail
      REPO_DIR="${openchamberDataDir}/repo"

      # Skip build if image already exists
      if docker image inspect "${openchamberImage}" >/dev/null 2>&1; then
        echo "Image ${openchamberImage} already exists, skipping build"
        exit 0
      fi

      # Clone or update source
      if [ ! -d "$REPO_DIR/.git" ]; then
        git clone --depth 1 --branch "${openchamberVersion}" \
          https://github.com/openchamber/openchamber.git "$REPO_DIR"
      else
        cd "$REPO_DIR"
        git fetch --depth 1 origin "refs/tags/${openchamberVersion}:refs/tags/${openchamberVersion}" 2>/dev/null || true
        git checkout "${openchamberVersion}"
      fi

      cd "$REPO_DIR"
      docker build -t "${openchamberImage}-base" .

      # Add /Users -> /home symlink for macOS path compatibility
      printf 'FROM ${openchamberImage}-base\nUSER root\nRUN ln -sfn /home /Users\nUSER openchamber\n' \
        | docker build -t "${openchamberImage}" -t openchamber:latest -
    '';
  };

  # --- OpenChamber: run container ---
  virtualisation.oci-containers = {
    backend = "docker";
    containers.openchamber = {
      image = openchamberImage;
      autoStart = true;
      user = "1000:1000";
      entrypoint = "/bin/sh";
      cmd = [
        "-c"
        "ln -sf /run/user/1000/agenix/id_ed25519.age /home/openchamber/.ssh/id_ed25519 && ln -sf /run/user/1000/agenix/id_ed25519.pub.age /home/openchamber/.ssh/id_ed25519.pub && exec /app/openchamber-entrypoint.sh"
      ];
      ports = [ "127.0.0.1:${toString openchamberPort}:3000" ];
      volumes = [
        "${homeDir}/.config/openchamber:/home/openchamber/.config/openchamber"
        "${homeDir}/.local/share/opencode:/home/openchamber/.local/share/opencode"
        "${homeDir}/.local/state/opencode:/home/openchamber/.local/state/opencode"
        "${homeDir}/.config/opencode:/home/openchamber/.config/opencode"
        "${homeDir}/.agents:/home/openchamber/.agents"
        # Nix store (read-only) — home-manager config files are symlinks into /nix/store
        "/nix/store:/nix/store:ro"
        # Agenix runtime secrets — /run/user/1000/agenix is a symlink to agenix.d/N/
        # Mount the parent so the full symlink chain resolves
        "/run/user/1000:/run/user/1000:ro"
        "${homeDir}/Dropbox:/home/openchamber/Dropbox"
      ];
      environment = {
        # UI_PASSWORD = ""; # Set via agenix if authentication is desired
      };
    };
  };

  # Container must wait for the image to be built and NFS Dropbox mount
  systemd.services.docker-openchamber = {
    after = [
      "openchamber-build.service"
      "home-kamushadenes-Dropbox.mount"
    ];
    requires = [ "openchamber-build.service" ];
    wants = [ "home-kamushadenes-Dropbox.mount" ];
  };

  # --- Persistent data directories ---
  systemd.tmpfiles.rules = [
    "d ${openchamberDataDir} 0755 root root -"
    "d ${openchamberDataDir}/repo 0755 root root -"
  ];
}
