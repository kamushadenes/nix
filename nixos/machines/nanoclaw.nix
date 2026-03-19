# Machine configuration for nanoclaw LXC
# NanoClaw - Personal AI agent for WhatsApp, Telegram, and more
# https://nanoclaw.dev / https://github.com/qwibitai/nanoclaw
#
# NanoClaw is a Node.js app that spawns Claude agents in isolated Docker
# containers. It connects to messaging apps (WhatsApp, Telegram) and manages
# per-group agent sessions with isolated filesystems.
#
# Initial setup after first deploy:
#   1. SSH into the LXC: ssh nanoclaw
#   2. Switch to nanoclaw user: sudo -u nanoclaw -i
#   3. cd /var/lib/nanoclaw/app
#   4. Run claude, then /setup to configure channels
#
# Adding channels (run inside claude on the LXC):
#   /add-whatsapp   — connects to WhatsApp (requires QR code scan)
#   /add-telegram   — connects to Telegram (requires bot token)
{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  private,
  ...
}:

let
  nodejs = pkgs.nodejs_22;
  nanoclaw-home = "/var/lib/nanoclaw";
  nanoclaw-app = "${nanoclaw-home}/app";
in
{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # Agenix secrets for NanoClaw
  age.secrets = {
    "nanoclaw-anthropic-key" = {
      file = "${private}/nixos/secrets/nanoclaw/anthropic-api-key.age";
      owner = "nanoclaw";
      group = "nanoclaw";
    };
  };

  # Create nanoclaw user (DynamicUser doesn't work with bind mounts)
  users.users.nanoclaw = {
    isSystemUser = true;
    group = "nanoclaw";
    home = nanoclaw-home;
    shell = pkgs.bash;
    createHome = true;
    # nanoclaw needs Docker access for spawning agent containers
    extraGroups = [ "docker" ];
  };
  users.groups.nanoclaw = { };

  # Enable Docker for NanoClaw agent container isolation
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # System packages: Node.js, git (for cloning/updating nanoclaw), and build tools
  environment.systemPackages = with pkgs; [
    nodejs
    git
    # Build dependencies for native Node.js modules (better-sqlite3)
    python3
    gnumake
    gcc
    # Claude Code for interactive NanoClaw setup (/setup, /add-whatsapp, /add-telegram)
    pkgs-unstable.claude-code
  ];

  # Oneshot service to clone and build NanoClaw on first boot
  # Only runs if /var/lib/nanoclaw/app doesn't exist yet
  systemd.services.nanoclaw-setup = {
    description = "NanoClaw - Initial clone and build";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    unitConfig = {
      # Skip if app directory already exists (already set up)
      ConditionPathExists = "!${nanoclaw-app}/package.json";
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "nanoclaw";
      Group = "nanoclaw";
      WorkingDirectory = nanoclaw-home;
    };

    path = [
      nodejs
      pkgs.git
      pkgs.gnumake
      pkgs.gcc
      pkgs.python3
      pkgs.coreutils
    ];

    script = ''
      set -euo pipefail

      echo "Cloning NanoClaw..."
      ${pkgs.git}/bin/git clone https://github.com/kamushadenes/nanoclaw.git ${nanoclaw-app}
      cd ${nanoclaw-app}
      ${pkgs.git}/bin/git remote add upstream https://github.com/qwibitai/nanoclaw.git

      echo "Installing dependencies..."
      cd ${nanoclaw-app}
      ${nodejs}/bin/npm install --no-audit --no-fund

      echo "Building..."
      ${nodejs}/bin/npm run build

      echo "NanoClaw setup complete"
    '';
  };

  # Main NanoClaw service
  systemd.services.nanoclaw = {
    description = "NanoClaw - Personal AI Agent";
    after = [
      "network-online.target"
      "docker.service"
      "nanoclaw-setup.service"
    ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];

    unitConfig = {
      # Don't start if app hasn't been set up yet
      ConditionPathExists = "${nanoclaw-app}/dist/index.js";
    };

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "10s";
      User = "nanoclaw";
      Group = "nanoclaw";
      StateDirectory = "nanoclaw";
      StateDirectoryMode = "0700";
      WorkingDirectory = nanoclaw-app;
      # Allow spawning Docker containers
      SupplementaryGroups = [ "docker" ];
    };

    path = [
      nodejs
      pkgs.git
      pkgs.docker
      pkgs.bash
      pkgs.coreutils
    ];

    script = ''
      export ANTHROPIC_API_KEY=$(cat ${config.age.secrets."nanoclaw-anthropic-key".path})

      exec ${nodejs}/bin/node dist/index.js
    '';
  };

  # Ensure data directory exists (don't create /app — git clone does that)
  systemd.tmpfiles.rules = [
    "d ${nanoclaw-home} 0700 nanoclaw nanoclaw -"
  ];

  # SSH: allow root login for remote deployment (headless role doesn't import minimal.nix)
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGqdVyJjYEVc0TfIAEa0OBtqSJJ6bVH1MQcuFnSG0ePp henrique.goncalves@henrique.goncalves"
  ];
  users.users.kamushadenes.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGqdVyJjYEVc0TfIAEa0OBtqSJJ6bVH1MQcuFnSG0ePp henrique.goncalves@henrique.goncalves"
  ];

  # Use persistent SSH host keys (survives ephemeral root rebuilds)
  services.openssh.hostKeys = [
    {
      path = "/nix/persist/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
    {
      path = "/nix/persist/etc/ssh/ssh_host_rsa_key";
      type = "rsa";
      bits = 4096;
    }
  ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;
}
