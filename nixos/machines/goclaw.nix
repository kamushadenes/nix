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
  packages,
  private,
  ...
}:

let
  goclaw-home = "/var/lib/goclaw";
  goclaw-app = "${goclaw-home}/app";
  # Fork (dev branch) with fixes for sandbox @ naming (#1031), stateless cron
  # reset (#1032), and credentialed CLI chain exec (#1033). Tracks dev branch
  # for latest features. Switch back to upstream after PRs merge.
  goclaw-repo = "https://github.com/kamushadenes/goclaw.git";
  # Disable the baked-in healthcheck — flaky MCP servers cause health
  # timeouts that mark the container unhealthy and stall the dashboard.
  goclaw-healthcheck-override = pkgs.writeText "docker-compose.healthcheck.yml" ''
    services:
      goclaw:
        healthcheck:
          disable: true
  '';
  # Override sandbox defaults: enable network (CLIs call external APIs)
  # and use custom image with pre-installed CLIs.
  goclaw-sandbox-overrides = pkgs.writeText "docker-compose.sandbox-overrides.yml" ''
    services:
      goclaw:
        environment:
          - GOCLAW_SANDBOX_NETWORK=true
          - GOCLAW_SANDBOX_IMAGE=goclaw-sandbox:custom
  '';
  # Custom sandbox Dockerfile with CLIs pre-installed (gh, gcloud, vt, fleetctl).
  goclaw-sandbox-dockerfile = pkgs.writeText "Dockerfile.sandbox.custom" ''
    FROM debian:bookworm-slim

    ENV DEBIAN_FRONTEND=noninteractive

    RUN apt-get update \
      && apt-get install -y --no-install-recommends \
        bash ca-certificates curl git jq python3 python3-pip ripgrep \
        gnupg unzip nodejs npm \
      && rm -rf /var/lib/apt/lists/*

    # GitHub CLI
    RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
      && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
      && apt-get update && apt-get install -y --no-install-recommends gh \
      && rm -rf /var/lib/apt/lists/*

    # FleetCtl (fleetdm/fleet) — direct binary, npm wrapper broken for non-root
    RUN FLEET_TAG=$(curl -fsSL https://api.github.com/repos/fleetdm/fleet/releases/latest | jq -r .tag_name) \
      && curl -fsSL "https://github.com/fleetdm/fleet/releases/download/$FLEET_TAG/fleetctl_''${FLEET_TAG#fleet-}_linux_amd64.tar.gz" \
        | tar -xz -C /usr/local/bin/ --strip-components=1 \
      && chmod +x /usr/local/bin/fleetctl

    # Google Cloud SDK (standalone tar, no apt repo needed)
    RUN curl -fsSL https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz \
        | tar -xz -C /opt \
      && /opt/google-cloud-sdk/install.sh --quiet --usage-reporting=false --path-update=false \
      && ln -s /opt/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud

    # ClickUp CLI (nicholasbester/clickup-cli) — installed at /app/data/.runtime/bin/
    # to match the Binary Path configured in GoClaw's Credentialed CLI settings
    RUN mkdir -p /app/data/.runtime/bin \
      && curl -fsSL https://github.com/nicholasbester/clickup-cli/releases/latest/download/clickup-linux-x86_64-musl.tar.gz \
        | tar -xz -C /app/data/.runtime/bin/ \
      && chmod +x /app/data/.runtime/bin/clickup

    # VirusTotal CLI
    RUN VT_VERSION=$(curl -fsSL https://api.github.com/repos/VirusTotal/vt-cli/releases/latest | jq -r .tag_name) \
      && curl -fsSL "https://github.com/VirusTotal/vt-cli/releases/download/''${VT_VERSION}/Linux64.zip" -o /tmp/vt.zip \
      && unzip -o /tmp/vt.zip -d /usr/local/bin/ && chmod +x /usr/local/bin/vt && rm /tmp/vt.zip

    # Runtime bin dir in PATH for credentialed exec resolution
    ENV PATH="/app/data/.runtime/bin:$PATH"

    RUN useradd --create-home --shell /bin/bash sandbox
    USER sandbox
    WORKDIR /home/sandbox

    CMD ["sleep", "infinity"]
  '';
  composeArgs = lib.concatStringsSep " " [
    "-f docker-compose.yml"
    "-f docker-compose.postgres.yml"
    "-f docker-compose.claude-cli.yml"
    "-f docker-compose.browser.yml"
    "-f docker-compose.otel.yml"
    "-f docker-compose.sandbox.yml"
    "-f docker-compose.redis.yml"
    "-f ${goclaw-sandbox-overrides}"
    "-f ${goclaw-healthcheck-override}"
  ];
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
  # and poppler_utils (pdftoppm/pdftocairo) that pdf2image shells out to.
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
    uv
  ];

  # Python env with document/PDF/LLM libraries for agent scripts. Installed
  # into root's home-manager profile with hiPrio so its `python3` wrapper wins
  # over the python312 that the shared `dev` role module already provides.
  home-manager.users.root.home.packages = [
    (lib.hiPrio (
      pkgs.python3.withPackages (ps: [
        ps.defusedxml
        ps.lxml
        ps.pdfplumber
        ps.pypdf
        ps.pdf2image
        ps.pillow
        ps.anthropic
        ps.openpyxl
      ])
    ))
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
      ${pkgs.git}/bin/git clone -b dev ${goclaw-repo} ${goclaw-app}

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
      # Build custom sandbox image with CLIs if not already present.
      # +prefix runs as root — docker build needs socket access.
      ExecStartPre =
        "+"
        + (pkgs.writeShellScript "goclaw-build-sandbox-image" ''
          if ! ${pkgs.docker}/bin/docker image inspect goclaw-sandbox:custom >/dev/null 2>&1; then
            echo "Building custom sandbox image..."
            ${pkgs.docker}/bin/docker build -t goclaw-sandbox:custom -f ${goclaw-sandbox-dockerfile} ${goclaw-app}
          fi
          # docker build runs as root and creates ~/.docker/buildx/ root-owned.
          # Chown so the goclaw user (ExecStart) can write buildx activity logs.
          ${pkgs.coreutils}/bin/chown -R goclaw:goclaw ${goclaw-home}/.docker 2>/dev/null || true
        '');
      # --build is required because the claude-cli overlay flips the
      # ENABLE_CLAUDE_CLI build arg, so the image must be built locally.
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose ${composeArgs} up -d --build";
      # Fix /app/data/.runtime perms so goclaw user can write github-packages.json.tmp
      # (upstream sets root:goclaw 0750 which blocks writes for github package installs)
      ExecStartPost = pkgs.writeShellScript "goclaw-fix-runtime-perms" ''
        for i in $(seq 1 30); do
          ${pkgs.docker-compose}/bin/docker-compose ${composeArgs} exec -T goclaw true 2>/dev/null && break
          sleep 2
        done
        ${pkgs.docker-compose}/bin/docker-compose ${composeArgs} exec -T -u root goclaw \
          sh -c 'chmod 0770 /app/data/.runtime 2>/dev/null || true'
        # Add goclaw user to docker group (GID of /var/run/docker.sock) so
        # agent-invoked wrappers (e.g. gcloud) can use docker-in-docker.
        ${pkgs.docker-compose}/bin/docker-compose ${composeArgs} exec -T -u root goclaw \
          sh -c 'addgroup -g 131 docker 2>/dev/null; addgroup goclaw docker 2>/dev/null; true'
      '';
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
