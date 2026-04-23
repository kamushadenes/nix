# Machine configuration for goclaw LXC
# GoClaw - Multi-tenant AI agent platform (Go + Postgres/pgvector)
# https://github.com/nextlevelbuilder/goclaw / https://docs.goclaw.sh
#
# Docker Compose stack (goclaw + postgres) runs as a systemd service. The
# application .env is generated on first boot by upstream prepare-env.sh
# (gateway token, encryption key) plus a random POSTGRES_PASSWORD. LLM
# provider keys are configured later via the web dashboard.
#
# Initial setup after first deploy:
#   1. Wait for goclaw-setup.service and goclaw.service to come up
#   2. Open http://10.23.23.9:18790 in a browser
#   3. Follow the setup wizard (providers, agents, channels)
{
  config,
  lib,
  pkgs,
  private,
  ...
}:

let
  goclaw-home = "/var/lib/goclaw";
  goclaw-app = "${goclaw-home}/app";
  goclaw-repo = "https://github.com/nextlevelbuilder/goclaw.git";
  composeArgs = "-f docker-compose.yml -f docker-compose.postgres.yml -f docker-compose.claude-cli.yml";
in
{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # Create goclaw user — needs docker group for running the compose stack
  users.users.goclaw = {
    isNormalUser = true;
    group = "goclaw";
    home = goclaw-home;
    shell = pkgs.bash;
    createHome = true;
    extraGroups = [ "docker" ];
  };
  users.groups.goclaw = { };

  # Enable Docker for GoClaw + Postgres compose stack
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # System packages: git (repo clone), docker-compose v2, build/crypto utilities,
  # cloud CLIs (gh, gcloud, aws, terraform) for agent workflows, postgresql_18
  # client tools (pg_dump/psql) matching the pgvector/pgvector:pg18 container,
  # and a Python env with document/PDF/LLM libraries for agent scripts.
  # poppler_utils provides the pdftoppm/pdftocairo binaries that pdf2image
  # shells out to at runtime.
  environment.systemPackages = with pkgs; [
    git
    docker-compose
    gnumake
    coreutils
    openssl
    gh
    google-cloud-sdk
    awscli2
    terraform
    postgresql_18
    poppler-utils
    (python3.withPackages (ps: [
      ps.defusedxml
      ps.lxml
      ps.pdfplumber
      ps.pypdf
      ps.pdf2image
      ps.pillow
      ps.anthropic
      ps.openpyxl
    ]))
  ];

  # Oneshot service: clone repo and seed .env on first boot. Subsequent boots
  # skip this (ConditionPathExists guard) so the existing .env is preserved.
  systemd.services.goclaw-setup = {
    description = "GoClaw - Initial clone and .env seed";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    unitConfig.ConditionPathExists = "!${goclaw-app}/docker-compose.yml";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "goclaw";
      Group = "goclaw";
      WorkingDirectory = goclaw-home;
      # Fix ownership on fresh deploys — the bind-mounted persist dir is
      # created root-owned before the goclaw user is provisioned, and
      # tmpfiles.d can race with the mount on the activation pass.
      ExecStartPre = "+${pkgs.coreutils}/bin/chown goclaw:goclaw ${goclaw-home}";
    };

    path = [
      pkgs.git
      pkgs.bash
      pkgs.openssl
      pkgs.coreutils
      pkgs.gnused
    ];

    script = ''
      set -euo pipefail

      echo "Cloning GoClaw..."
      ${pkgs.git}/bin/git clone -b main ${goclaw-repo} ${goclaw-app}

      echo "Generating .env via prepare-env.sh..."
      cd ${goclaw-app}
      ${pkgs.bash}/bin/bash ./prepare-env.sh

      # prepare-env.sh generates GOCLAW_GATEWAY_TOKEN and GOCLAW_ENCRYPTION_KEY
      # but leaves POSTGRES_PASSWORD blank. Fill it with a random value so
      # Postgres does not fall back to the dev default.
      if ! ${pkgs.gnused}/bin/sed -n 's/^POSTGRES_PASSWORD=\(.*\)$/\1/p' .env | grep -q '.'; then
        pw=$(${pkgs.openssl}/bin/openssl rand -hex 32)
        if grep -qE '^POSTGRES_PASSWORD=' .env; then
          ${pkgs.gnused}/bin/sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$pw|" .env
        else
          echo "POSTGRES_PASSWORD=$pw" >> .env
        fi
      fi

      echo "GoClaw setup complete"
    '';
  };

  # Main service: bring the compose stack up/down with systemd
  systemd.services.goclaw = {
    description = "GoClaw - Multi-Tenant AI Agent Platform (docker compose)";
    after = [
      "network-online.target"
      "docker.service"
      "goclaw-setup.service"
    ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];

    unitConfig.ConditionPathExists = "${goclaw-app}/docker-compose.yml";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "goclaw";
      Group = "goclaw";
      WorkingDirectory = goclaw-app;
      # --build is required because the claude-cli overlay flips the
      # ENABLE_CLAUDE_CLI build arg, so the image must be built locally.
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose ${composeArgs} up -d --build";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose ${composeArgs} down";
    };

    path = [
      pkgs.docker
      pkgs.docker-compose
      pkgs.git
      pkgs.coreutils
    ];
  };

  # Data directory (compose volumes live under /var/lib/docker)
  systemd.tmpfiles.rules = [
    "d ${goclaw-home} 0750 goclaw goclaw -"
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
