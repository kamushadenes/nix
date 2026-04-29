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
  pkgs-unstable,
  packages,
  private,
  ...
}:

let
  goclaw-home = "/var/lib/goclaw";
  goclaw-app = "${goclaw-home}/app";
  # Musl variant of clickup-cli. Goclaw's GitHub Packages installer (configured
  # via the dashboard) downloads the glibc tar by default, which fails to link
  # against the sandbox's bookworm-slim glibc. We overwrite the binary in the
  # shared `app_goclaw-data` volume after install; the sandbox Dockerfile bake
  # is masked by the volume mount so it cannot be the fix.
  goclaw-clickup-version = "v0.9.1";
  goclaw-clickup-musl-url = "https://github.com/nicholasbester/clickup-cli/releases/download/${goclaw-clickup-version}/clickup-linux-x86_64-musl.tar.gz";
  goclaw-clickup-musl-tar-sha256 = "1569561aeb67eded9c2e8a93b2301ab7f7beaffdecb9684f8ff0a991c9c24684";
  goclaw-clickup-musl-bin-sha256 = "da85b728b2dde96c8c708ca6801ac11d0ee169f55c3575b0c9e83df3ece89b83";
  goclaw-clickup-musl-tar-bytes = 5421629;
  # Pinned google-cloud-sdk install. The default `gcloud` shim in the goclaw
  # image is a docker-run wrapper that breaks in the sandbox (no docker
  # socket). We replace it with the real SDK extracted into the shared
  # `app_goclaw-data` volume so main and sandbox both run the same binary
  # at the same path. Alpine compatibility relies on `gcompat` and the
  # system python3 (CLOUDSDK_PYTHON) — bundled CPython is glibc-only.
  goclaw-gcloud-version = "565.0.0";
  goclaw-gcloud-url = "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${goclaw-gcloud-version}-linux-x86_64.tar.gz";
  goclaw-gcloud-tar-sha256 = "733e3640b5892baecd997474cb1b2cfe80204b6584c64166c3d78bae3f1108c3";
  # GAM-team/GAM (gam7) — pyinstaller-frozen Python binary. The
  # "glibc2.35" variant ships a partial set of vendored libs
  # (libpython3.14, libssl, etc.) that conflict with Alpine's
  # musl/gcompat at relocation time (`crc32_z`, `preadv64v2` and
  # similar symbols missing). The "legacy" variant uses staticx, which
  # extracts the entire bundle to /tmp and execs it from there —
  # cleaner because it ships its own glibc and has no host-libc
  # dependencies. To make that variant work in our sandbox we drop
  # `noexec` from the tmpfs mount via GOCLAW_SANDBOX_TMP_EXEC=true
  # (requires the goclaw fork's AllowTmpExec patch).
  goclaw-gam-version = "7.42.00";
  goclaw-gam-url = "https://github.com/GAM-team/GAM/releases/download/v${goclaw-gam-version}/gam-${goclaw-gam-version}-linux-x86_64-legacy.tar.xz";
  goclaw-gam-tar-sha256 = "bb912086c49f9421b24ee885263b4361327716ed4c9e049512a5022e5a63d6a8";
  goclaw-data-vol = "/var/lib/docker/volumes/app_goclaw-data/_data";

  # Upstream himalaya v1.2.0 release binaries are built without the
  # `oauth2` cargo feature, so they cannot speak XOAUTH2 to Gmail. Override
  # the nixpkgs derivation to enable it. `oauth2` transitively pulls in
  # `keyring`, which is harmless for us because the materialized TOML
  # never requests keyring lookups (all secrets resolve via `*.cmd =
  # "printenv ..."`).
  #
  # Use `pkgsStatic` so the resulting binary is a fully static-musl ELF:
  # no /nix/store interp path baked in (a vanilla nixpkgs build's rpath
  # references a glibc store path the sandbox cannot reach), and no
  # reliance on Alpine's gcompat for missing glibc symbols
  # (gcompat lacks `__register_atfork`, `__res_init`, etc., which the
  # standard build pulls in via libc.so.6).
  himalaya-oauth2 = pkgs-unstable.pkgsStatic.himalaya.override {
    buildNoDefaultFeatures = true;
    buildFeatures = [
      "imap"
      "smtp"
      "sendmail"
      "maildir"
      "wizard"
      "pgp-commands"
      "oauth2"
    ];
  };
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
  #
  # Also patches three runtime limits that broke S3 backups:
  #
  #   1. cap_add: KILL — upstream base compose drops ALL caps and re-adds
  #      only SETUID/SETGID/CHOWN (+ NET_BIND_SERVICE in sandbox.yml). With
  #      no CAP_KILL, tini PID 1 (root) cannot forward signals to the
  #      goclaw process (uid 1000) because Linux requires CAP_KILL when
  #      sender uid != receiver uid. Any catchable signal to PID 1 (Docker
  #      stop, compose recreate) then triggers
  #      `[FATAL tini (1)] Unexpected error when forwarding signal:
  #      'Operation not permitted'` and the container restart-loops.
  #
  #   2. memory: 4G — upstream caps the container at 1 GiB. The S3 backup
  #      handler buffers the entire pg_dump output in memory
  #      (internal/backup/backup.go: `var dbBuf bytes.Buffer`). With
  #      /app/data ≈ 1.3 GB the SQL dump exceeds 1 GiB and the cgroup
  #      OOM-kills goclaw mid-backup. Bumping to 4 GiB gives headroom
  #      until upstream switches to a streaming pg_dump → tar pipeline.
  #
  #   3. tmpfs /tmp size=2g — upstream caps /tmp at 256 MiB. Backups land
  #      at `os.CreateTemp("", "goclaw-backup-*.tar.gz")` which writes to
  #      /tmp, so the archive itself blows out the tmpfs once DB+files
  #      cross 256 MiB. `!override` is required because compose merges
  #      `tmpfs:` lists by concatenation — duplicate /tmp entries error.
  #      nosuid is preserved; noexec dropped to match the existing
  #      sandbox tmpfs exec policy.
  goclaw-sandbox-overrides = pkgs.writeText "docker-compose.sandbox-overrides.yml" ''
    services:
      goclaw:
        environment:
          - GOCLAW_SANDBOX_NETWORK=true
          - GOCLAW_SANDBOX_IMAGE=goclaw-sandbox:custom
          # Drop `noexec` from sandbox tmpfs mounts so staticx-wrapped
          # CLIs (e.g. gam7 legacy variant) can extract+exec from /tmp.
          # Requires the goclaw fork's AllowTmpExec patch on the dev
          # branch. nosuid + nodev still enforced.
          - GOCLAW_SANDBOX_TMP_EXEC=true
        cap_add:
          - KILL
        tmpfs: !override
          - /tmp:rw,nosuid,size=2g
        deploy:
          resources:
            limits:
              memory: 4G
              cpus: '2.0'
              pids: 200
  '';
  # Persist /app/.google_workspace_mcp/ across container recreations. Without
  # this, the OAuth credential store (created by `uvx workspace-mcp` under the
  # goclaw user) lives in the writable layer and is wiped every time
  # docker compose --build recreates the container, forcing re-auth.
  # Bind-mount instead of named volume so host-side tmpfiles can pre-create
  # the dir with goclaw:goclaw (1000:1000) ownership — anonymous volumes
  # bind-mounted to a path absent from the image come up root-owned and the
  # non-root goclaw user inside the container cannot write to them.
  goclaw-mcp-creds-host = "${goclaw-home}/mcp-creds/google_workspace_mcp";
  goclaw-mcp-creds-override = pkgs.writeText "docker-compose.mcp-creds.yml" ''
    services:
      goclaw:
        volumes:
          - ${goclaw-mcp-creds-host}:/app/.google_workspace_mcp
  '';
  # Expose google_workspace_mcp OAuth callback ports. workspace-mcp binds
  # 48888/48889 (one per configured tenant: iniciador, hadenes) only while an
  # OAuth flow is active; the publish is harmless when the listener is absent.
  goclaw-mcp-ports-override = pkgs.writeText "docker-compose.mcp-ports.yml" ''
    services:
      goclaw:
        ports:
          - "48888:48888"
          - "48889:48889"
  '';
  # Custom sandbox Dockerfile. Alpine base matches the main goclaw container
  # (musl) so binaries shared via the `app_goclaw-data` volume mount link
  # consistently against the same libc — no glibc/musl divergence between
  # host and sandbox. The image only bakes core tooling (bash, git, jq,
  # python3, node, etc.) plus the apk `github-cli` package; every other
  # CLI (gcloud, vt, clickup, vanta-cli, rtk, fleetctl, agent-slack, …)
  # ships through the shared volume from goclaw's dashboard installer.
  goclaw-sandbox-dockerfile = pkgs.writeText "Dockerfile.sandbox.custom" ''
    FROM alpine:3.23

    # Core tooling. github-cli lives in community repo (enabled by default).
    # gcompat provides glibc symbols for binaries built against glibc (e.g. vt
    # from the volume). Matches the main goclaw container's compat layer.
    RUN apk add --no-cache \
        bash ca-certificates curl git jq python3 py3-pip ripgrep \
        gnupg unzip nodejs npm openssh-client-default \
        github-cli shadow gcompat

    # No CLI bakes beyond `gh` (the apk package above): every other CLI
    # we run in the sandbox is delivered through the `app_goclaw-data`
    # volume mounted at /app/data, populated by the goclaw dashboard's
    # CLI Tools installer (Node Packages → /app/data/.runtime/npm-global,
    # GitHub Binaries → /app/data/.runtime/bin). Now that the sandbox base
    # matches main's libc and `HOME=/tmp` lets non-root npm wrappers write
    # their per-user state to tmpfs, those volume binaries run cleanly —
    # baking duplicates them and ages out independently.
    #
    # Host-side services patch two volume binaries that goclaw's installer
    # ships in a sandbox-incompatible form:
    #   - goclaw-clickup-musl.service swaps the glibc clickup tar for the
    #     musl variant.
    #   - goclaw-gcloud-real.service replaces the default docker-run gcloud
    #     wrapper with the real Google Cloud SDK so the sandbox (which has
    #     no docker socket) can run `gcloud` directly.

    # Runtime bin dirs in PATH for credentialed exec resolution. Both
    # /app/data/.runtime/bin (GitHub Binaries) and the npm-global bin dir
    # (Node Packages) come from the shared volume.
    ENV PATH="/app/data/.runtime/bin:/app/data/.runtime/npm-global/bin:$PATH"

    # Pip packages installed by goclaw dashboard ("Pip Packages" section)
    # land in the shared volume at /app/data/.runtime/pip — expose them on
    # PYTHONPATH so any python script in the sandbox imports them without
    # extra flags.
    ENV PYTHONPATH="/app/data/.runtime/pip"

    # Symlink /app/workspace → /workspace so main container paths
    # (e.g. /app/workspace/uhura/cron/system) resolve in sandbox.
    RUN mkdir -p /app && ln -s /workspace /app/workspace

    # SSH key + system ssh_config baked from the build context (see
    # goclaw-sandbox-build-context script). Path is /etc/goclaw-ssh/...
    # so it does NOT match the always-on /app/data shell deny pattern.
    # Key is decrypted from agenix at boot and staged into the build
    # context; ssh_config is generated inline alongside it.
    # Legacy docker builder doesn't support --chmod on COPY, so chmod
    # in a follow-on RUN. BuildKit is disabled here because the LXC
    # has no DBus secret service for credential helpers.
    RUN mkdir -p /etc/goclaw-ssh
    COPY --chown=1000:1000 sandbox-id_ed25519 /etc/goclaw-ssh/id_ed25519
    COPY --chown=root:root sandbox-ssh-config /etc/ssh/ssh_config
    RUN chmod 0400 /etc/goclaw-ssh/id_ed25519 && chmod 0644 /etc/ssh/ssh_config

    # `shadow` provides useradd; bash is installed above. Goclaw spawns
    # sandbox containers with read-only rootfs — only /tmp, /var/tmp and
    # /workspace are writable. Point both the passwd entry and $HOME at
    # /tmp so CLIs that read from `os/user.Current()` (e.g. fleetctl
    # writing ~/.goquery) and CLIs that read $HOME (e.g. gcloud writing
    # ~/.config) both land on tmpfs instead of crashing with "Read-only
    # file system". State is ephemeral, which matches the sandbox model.
    RUN useradd --shell /bin/bash --home-dir /tmp sandbox
    USER sandbox
    ENV HOME=/tmp
    WORKDIR /tmp

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
    "-f ${goclaw-mcp-creds-override}"
    "-f ${goclaw-mcp-ports-override}"
  ];
in
{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # Encrypted fleetctl config (YAML) — populated by goclaw-fleetctl-config.service
  # into the shared volume so the sandbox sees it via $CONFIG.
  age.secrets."goclaw-fleetctl-config" = {
    file = "${private}/nixos/secrets/goclaw/fleetctl-config.age";
    # Default decrypt path /run/agenix/goclaw-fleetctl-config; readable by root.
    mode = "0400";
    owner = "root";
    group = "root";
  };

  # Encrypted himalaya config TOML covering Fastmail + the two Gmail
  # accounts (Hadenes, Iniciador) via app passwords. Materialized into
  # the shared volume by goclaw-cli-secrets.service so the sandbox can
  # point HIMALAYA_CONFIG at it.
  age.secrets."goclaw-himalaya-config" = {
    file = "${private}/nixos/secrets/goclaw/himalaya-config.age";
    mode = "0400";
    owner = "root";
    group = "root";
  };

  # Encrypted gam7 service-account JSON key (Iniciador tenant only).
  # Service-account auth means gam7 mints JWTs per call; no refresh-token
  # cache to write back, which sidesteps the read-only sandbox volume
  # problem.
  age.secrets."goclaw-gam7-iniciador-sa" = {
    file = "${private}/nixos/secrets/goclaw/gam7-iniciador-sa.age";
    mode = "0400";
    owner = "root";
    group = "root";
  };

  # gam7 main config (gam.cfg) for the Iniciador tenant — paths, domain,
  # admin_email defaults. Sandbox uses GAMCFGDIR=/app/data/.runtime/gam7/iniciador.
  age.secrets."goclaw-gam7-iniciador-cfg" = {
    file = "${private}/nixos/secrets/goclaw/gam7-iniciador-cfg.age";
    mode = "0400";
    owner = "root";
    group = "root";
  };

  # gam7 OAuth user-token cache (oauth2.txt). gam7 emits it via
  # `gam oauth create` after a browser consent flow; we materialize it
  # alongside oauth2service.json so gam runs that hit user-OAuth code
  # paths (rather than pure SA) find the cached refresh_token.
  age.secrets."goclaw-gam7-iniciador-oauth2" = {
    file = "${private}/nixos/secrets/goclaw/gam7-iniciador-oauth2.age";
    mode = "0400";
    owner = "root";
    group = "root";
  };

  # gam7 OAuth client_secrets.json — registered Google API client
  # (id + secret + redirect URIs). gam needs it alongside oauth2.txt
  # to refresh user-OAuth access tokens. Without it gam returns
  # "API access Denied" because the refresh request has no client.
  age.secrets."goclaw-gam7-iniciador-client-secrets" = {
    file = "${private}/nixos/secrets/goclaw/gam7-iniciador-client-secrets.age";
    mode = "0400";
    owner = "root";
    group = "root";
  };

  # gcalcli per-tenant OAuth credential files (google.oauth2.credentials
  # JSON: refresh_token + client_id + client_secret + scopes).
  # Materialized into the shared volume and copied to /tmp by the
  # gcalcli-<tenant> wrappers at runtime — gcalcli writes refreshed
  # access tokens into config_folder/oauth, so the volume copy stays
  # static and the writable copy lives on tmpfs per spawn.
  age.secrets."goclaw-gcalcli-hadenes-oauth" = {
    file = "${private}/nixos/secrets/goclaw/gcalcli-hadenes-oauth.age";
    mode = "0400";
    owner = "root";
    group = "root";
  };
  age.secrets."goclaw-gcalcli-iniciador-oauth" = {
    file = "${private}/nixos/secrets/goclaw/gcalcli-iniciador-oauth.age";
    mode = "0400";
    owner = "root";
    group = "root";
  };

  # SSH private key baked into the sandbox image at /etc/goclaw-ssh/id_ed25519.
  # Sandbox containers only mount app_goclaw-data:/app/data:ro, and that path
  # is always-on path-denied (cmd/gateway_setup.go DenyPaths). Per-agent
  # shell_deny_groups can opt out of the network_recon ssh-egress regex but
  # cannot override the path deny. Image is built locally and never pushed.
  age.secrets."goclaw-sandbox-ssh-key" = {
    file = "${private}/nixos/secrets/goclaw/sandbox-ssh-key.age";
    mode = "0400";
    owner = "root";
    group = "root";
  };

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

    # Re-run when the sandbox SSH key rotates so the image rebuild
    # ExecStartPre picks up the new key. The unit is oneshot +
    # RemainAfterExit, which would otherwise stay "active" across
    # rebuilds and skip the rebuild check.
    restartTriggers = [
      config.age.secrets."goclaw-sandbox-ssh-key".file
    ];

    unitConfig.ConditionPathExists = "${goclaw-app}/docker-compose.yml";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "goclaw";
      Group = "goclaw";
      WorkingDirectory = goclaw-app;
      # Build custom sandbox image and reap orphan sandbox containers.
      # +prefix runs as root — docker build/rm need socket access.
      ExecStartPre =
        "+"
        + (pkgs.writeShellScript "goclaw-build-sandbox-image" ''
          # Rebuild whenever the Dockerfile, SSH key, or ssh_config content
          # changes. The build hash now covers all three so the image is
          # regenerated on key rotation as well as Dockerfile edits.
          dockerfile="${goclaw-sandbox-dockerfile}"
          ssh_key=${config.age.secrets."goclaw-sandbox-ssh-key".path}
          build_dir=${goclaw-home}/sandbox-build

          ${pkgs.coreutils}/bin/install -d -m 0700 -o root -g root "$build_dir"

          # Stage the SSH key (decrypted plaintext). Build context owns
          # the file briefly; image bake fixes ownership to uid 1000 so the
          # sandbox user can read it without world-permissive perms.
          ${pkgs.coreutils}/bin/install -m 0400 -o root -g root \
            "$ssh_key" "$build_dir/sandbox-id_ed25519"

          # Stage the system ssh_config so plain `ssh root@10.23.5.x`
          # resolves IdentityFile + User without -i/-l flags.
          ${pkgs.coreutils}/bin/cat > "$build_dir/sandbox-ssh-config" <<'EOF'
          Host pve1 pve2 pve3 10.23.5.10 10.23.5.11 10.23.5.12
              User root
              IdentityFile /etc/goclaw-ssh/id_ed25519
              StrictHostKeyChecking accept-new
              UserKnownHostsFile /tmp/.ssh-known-hosts
          EOF
          ${pkgs.coreutils}/bin/chmod 0644 "$build_dir/sandbox-ssh-config"

          # Copy the Dockerfile into the build context.
          ${pkgs.coreutils}/bin/install -m 0644 "$dockerfile" "$build_dir/Dockerfile"

          want_hash=$(${pkgs.coreutils}/bin/cat \
            "$build_dir/Dockerfile" \
            "$build_dir/sandbox-ssh-config" \
            "$build_dir/sandbox-id_ed25519" \
            | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)
          have_hash=$(${pkgs.docker}/bin/docker image inspect goclaw-sandbox:custom \
            --format '{{ index .Config.Labels "dockerfile.sha256" }}' 2>/dev/null || true)
          if [ "$want_hash" != "$have_hash" ]; then
            echo "Building custom sandbox image (build hash=$want_hash)..."
            # DOCKER_BUILDKIT=0 falls back to the legacy builder. Buildkit on
            # this LXC fails to resolve the image registry credentials store
            # (no DBus secret service available); the legacy builder reads
            # /root/.docker/config.json directly and works headlessly.
            DOCKER_BUILDKIT=0 ${pkgs.docker}/bin/docker build \
              --label "dockerfile.sha256=$want_hash" \
              -t goclaw-sandbox:custom \
              -f "$build_dir/Dockerfile" \
              "$build_dir"
          fi
          # docker build runs as root and creates ~/.docker/buildx/ root-owned.
          # Chown so the goclaw user (ExecStart) can write buildx activity logs.
          ${pkgs.coreutils}/bin/chown -R goclaw:goclaw ${goclaw-home}/.docker 2>/dev/null || true
          # Reap orphan sandbox containers from prior goclaw process. Upstream
          # sandbox manager keeps an in-memory map only; on restart, deterministic-
          # named containers (agent/session scope) collide with the existing ones
          # and `docker run --name X` fails with "Conflict. The container name is
          # already in use". Pruning in upstream walks the in-memory map only,
          # so orphans are never reclaimed. Nuking them here is safe — the new
          # goclaw process will recreate them on demand.
          orphans=$(${pkgs.docker}/bin/docker ps -aq --filter label=goclaw.sandbox=true)
          if [ -n "$orphans" ]; then
            echo "Reaping $(echo "$orphans" | wc -l) orphan sandbox container(s)..."
            echo "$orphans" | ${pkgs.findutils}/bin/xargs ${pkgs.docker}/bin/docker rm -f >/dev/null 2>&1 || true
          fi
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

  # Replace clickup with musl variant after goclaw installs the glibc default.
  # Idempotent: skips when the binary already matches the pinned musl sha.
  # Also rewrites github-packages.json so goclaw's verifier sees a consistent
  # asset URL/sha pair and does not attempt to re-download the glibc tar.
  systemd.services.goclaw-clickup-musl = {
    description = "Replace goclaw clickup binary with musl variant";
    after = [ "goclaw.service" ];
    wants = [ "goclaw.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    path = [
      pkgs.curl
      pkgs.coreutils
      pkgs.gnutar
      pkgs.gzip
      pkgs.jq
    ];

    script = ''
      set -euo pipefail

      bin=${goclaw-data-vol}/.runtime/bin/clickup
      manifest=${goclaw-data-vol}/.runtime/github-packages.json
      target_sha="${goclaw-clickup-musl-bin-sha256}"

      for _ in $(seq 1 60); do
        [ -f "$bin" ] && break
        sleep 2
      done
      if [ ! -f "$bin" ]; then
        echo "clickup not yet installed by goclaw; nothing to replace"
        exit 0
      fi

      cur_sha=$(sha256sum "$bin")
      cur_sha=''${cur_sha%% *}
      if [ "$cur_sha" = "$target_sha" ]; then
        echo "clickup already musl variant ($target_sha)"
      else
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        curl -fsSL "${goclaw-clickup-musl-url}" -o "$tmp/clickup.tar.gz"
        tar -xzf "$tmp/clickup.tar.gz" -C "$tmp"
        install -m 0755 -o 1000 -g 1000 "$tmp/clickup" "$bin"
        echo "clickup replaced with musl variant"
      fi

      if [ -f "$manifest" ]; then
        jq \
          --arg url "${goclaw-clickup-musl-url}" \
          --arg sha "${goclaw-clickup-musl-tar-sha256}" \
          --arg name "clickup-linux-x86_64-musl.tar.gz" \
          --argjson size ${toString goclaw-clickup-musl-tar-bytes} \
          '(.packages[] | select(.name=="clickup")) |= (.asset_url=$url | .sha256=$sha | .asset_name=$name | .asset_size_bytes=$size)' \
          "$manifest" > "$manifest.new"
        if ! cmp -s "$manifest.new" "$manifest"; then
          mv "$manifest.new" "$manifest"
          chown 1000:1000 "$manifest"
          chmod 0644 "$manifest"
          echo "github-packages.json updated to musl asset"
        else
          rm -f "$manifest.new"
        fi
      fi
    '';
  };

  # Replace goclaw's docker-run gcloud wrapper with the real Google Cloud SDK.
  # The default wrapper at /app/data/.runtime/bin/gcloud spawns the gcloud
  # docker image — fine in the main container (which has /var/run/docker.sock)
  # but broken inside sandboxes (no docker socket, by design). Extract the
  # real SDK into the shared volume and replace the wrapper with a thin shim
  # that uses Alpine's system python (CLOUDSDK_PYTHON). gcompat in both
  # containers handles glibc-linked SDK helpers. Idempotent: skips when the
  # SDK directory already reports the pinned version.
  systemd.services.goclaw-gcloud-real = {
    description = "Replace goclaw gcloud docker-wrapper with real SDK";
    after = [ "goclaw.service" ];
    wants = [ "goclaw.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    path = [
      pkgs.curl
      pkgs.coreutils
      pkgs.gnutar
      pkgs.gzip
    ];

    script = ''
      set -euo pipefail

      sdk_dir=${goclaw-data-vol}/.runtime/google-cloud-sdk
      shim=${goclaw-data-vol}/.runtime/bin/gcloud
      target_version="${goclaw-gcloud-version}"

      for _ in $(seq 1 60); do
        [ -d "${goclaw-data-vol}/.runtime/bin" ] && break
        sleep 2
      done
      if [ ! -d "${goclaw-data-vol}/.runtime/bin" ]; then
        echo ".runtime/bin not present yet; nothing to do"
        exit 0
      fi

      current_version=""
      [ -f "$sdk_dir/VERSION" ] && current_version=$(cat "$sdk_dir/VERSION")
      if [ "$current_version" != "$target_version" ]; then
        echo "Installing google-cloud-sdk $target_version (current: ''${current_version:-none})..."
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        curl -fsSL "${goclaw-gcloud-url}" -o "$tmp/sdk.tar.gz"
        echo "${goclaw-gcloud-tar-sha256}  $tmp/sdk.tar.gz" | sha256sum -c -
        rm -rf "$sdk_dir"
        mkdir -p "$sdk_dir"
        tar -xzf "$tmp/sdk.tar.gz" -C "$sdk_dir" --strip-components=1
        echo "$target_version" > "$sdk_dir/VERSION"
        chown -R 1000:1000 "$sdk_dir"
        echo "google-cloud-sdk installed at $target_version"
      else
        echo "google-cloud-sdk already at $target_version"
      fi

      shim_content='#!/bin/sh
exec env CLOUDSDK_PYTHON=/usr/bin/python3 /app/data/.runtime/google-cloud-sdk/bin/gcloud "$@"'
      desired_sha=$(printf '%s\n' "$shim_content" | sha256sum | cut -d' ' -f1)
      current_sha=""
      [ -f "$shim" ] && current_sha=$(sha256sum "$shim" | cut -d' ' -f1)
      if [ "$desired_sha" != "$current_sha" ]; then
        printf '%s\n' "$shim_content" > "$shim.new"
        chmod 0755 "$shim.new"
        chown 1000:1000 "$shim.new"
        mv "$shim.new" "$shim"
        echo "gcloud shim updated"
      else
        echo "gcloud shim already up to date"
      fi
    '';
  };

  # fleetctl config materializer. fleetctl reads server address and auth
  # token exclusively from a YAML config file. The only env it honours
  # are $CONFIG (config file path), $CONTEXT, $DEBUG, $EMAIL, $PASSWORD —
  # never $FLEET_URL or $FLEET_TOKEN — so goclaw's CLI Tool credential
  # injection can't configure it directly. Instead, decrypt the agenix
  # secret containing the full fleetctl config YAML and drop it into the
  # shared volume at a path the sandbox sees read-only via /app/data.
  # The dashboard's fleetctl CLI Tool entry should set binary_path to
  # /app/data/.runtime/bin/fleetctl (the real binary) and inject
  # CONFIG=/app/data/.runtime/fleet/config; the sandbox tmpfs $HOME stays
  # untouched. Idempotent on file sha.
  systemd.services.goclaw-fleetctl-config = {
    description = "Materialize fleetctl config into goclaw shared volume";
    after = [
      "goclaw.service"
      "agenix.service"
    ];
    wants = [
      "goclaw.service"
      "agenix.service"
    ];
    wantedBy = [ "multi-user.target" ];

    # Re-run when the encrypted source changes. The service is
    # oneshot+RemainAfterExit, so without this it stays "active" across
    # rebuilds and never re-copies new agenix output to the volume after
    # the secret is edited.
    restartTriggers = [
      config.age.secrets."goclaw-fleetctl-config".file
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    path = [
      pkgs.coreutils
    ];

    script = ''
      set -euo pipefail

      src=${config.age.secrets."goclaw-fleetctl-config".path}
      dest_dir=${goclaw-data-vol}/.runtime/fleet
      dest=$dest_dir/config

      for _ in $(seq 1 60); do
        [ -d "${goclaw-data-vol}/.runtime" ] && break
        sleep 2
      done
      if [ ! -d "${goclaw-data-vol}/.runtime" ]; then
        echo ".runtime not present yet; nothing to do"
        exit 0
      fi

      if [ ! -s "$src" ]; then
        echo "agenix secret $src missing or empty; skipping"
        exit 0
      fi

      mkdir -p "$dest_dir"
      chown 1000:1000 "$dest_dir"
      chmod 0750 "$dest_dir"

      desired_sha=$(sha256sum "$src" | cut -d' ' -f1)
      current_sha=""
      [ -f "$dest" ] && current_sha=$(sha256sum "$dest" | cut -d' ' -f1)
      if [ "$desired_sha" != "$current_sha" ]; then
        # 0600 required by fleetctl; sandbox rootfs is read-only so
        # `fleetctl` cannot self-chmod after the fact.
        install -m 0600 -o 1000 -g 1000 "$src" "$dest"
        echo "fleetctl config materialized at $dest"
      else
        echo "fleetctl config already up to date"
      fi
    '';
  };

  # himalaya + gam7 credential materializer. Same pattern as
  # goclaw-fleetctl-config: decrypt agenix-managed source files and copy
  # them into the shared volume at well-known paths the dashboard CLI
  # Tool entries point at via env (HIMALAYA_CONFIG, GAM_CONFIG_DIR).
  # Idempotent on per-file sha; re-runs on .age content change via
  # restartTriggers since the unit is oneshot+RemainAfterExit.
  systemd.services.goclaw-cli-secrets = {
    description = "Materialize himalaya + gam7 secrets into goclaw shared volume";
    after = [
      "goclaw.service"
      "agenix.service"
    ];
    wants = [
      "goclaw.service"
      "agenix.service"
    ];
    wantedBy = [ "multi-user.target" ];

    restartTriggers = [
      config.age.secrets."goclaw-himalaya-config".file
      config.age.secrets."goclaw-gam7-iniciador-sa".file
      config.age.secrets."goclaw-gam7-iniciador-cfg".file
      config.age.secrets."goclaw-gam7-iniciador-oauth2".file
      config.age.secrets."goclaw-gam7-iniciador-client-secrets".file
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    path = [
      pkgs.coreutils
    ];

    script = ''
      set -euo pipefail

      himalaya_src=${config.age.secrets."goclaw-himalaya-config".path}
      himalaya_dest_dir=${goclaw-data-vol}/.runtime/himalaya
      himalaya_dest=$himalaya_dest_dir/config.toml

      gam_iniciador_src=${config.age.secrets."goclaw-gam7-iniciador-sa".path}
      gam_iniciador_dest_dir=${goclaw-data-vol}/.runtime/gam7/iniciador
      gam_iniciador_dest=$gam_iniciador_dest_dir/oauth2service.json

      gam_iniciador_cfg_src=${config.age.secrets."goclaw-gam7-iniciador-cfg".path}
      gam_iniciador_cfg_dest=$gam_iniciador_dest_dir/gam.cfg

      gam_iniciador_oauth2_src=${config.age.secrets."goclaw-gam7-iniciador-oauth2".path}
      gam_iniciador_oauth2_dest=$gam_iniciador_dest_dir/oauth2.txt

      gam_iniciador_cs_src=${config.age.secrets."goclaw-gam7-iniciador-client-secrets".path}
      gam_iniciador_cs_dest=$gam_iniciador_dest_dir/client_secrets.json

      for _ in $(seq 1 60); do
        [ -d "${goclaw-data-vol}/.runtime" ] && break
        sleep 2
      done
      if [ ! -d "${goclaw-data-vol}/.runtime" ]; then
        echo ".runtime not present yet; nothing to do"
        exit 0
      fi

      materialize() {
        src=$1; dest_dir=$2; dest=$3; label=$4
        if [ ! -s "$src" ]; then
          echo "agenix secret $src missing or empty; skipping $label"
          return 0
        fi
        mkdir -p "$dest_dir"
        chown 1000:1000 "$dest_dir"
        chmod 0750 "$dest_dir"
        desired_sha=$(sha256sum "$src" | cut -d' ' -f1)
        current_sha=""
        [ -f "$dest" ] && current_sha=$(sha256sum "$dest" | cut -d' ' -f1)
        if [ "$desired_sha" != "$current_sha" ]; then
          install -m 0600 -o 1000 -g 1000 "$src" "$dest"
          echo "$label materialized at $dest"
        else
          echo "$label already up to date"
        fi
      }

      materialize "$himalaya_src"          "$himalaya_dest_dir"      "$himalaya_dest"          "himalaya config"
      materialize "$gam_iniciador_src"        "$gam_iniciador_dest_dir" "$gam_iniciador_dest"        "gam7 iniciador SA"
      materialize "$gam_iniciador_cfg_src"    "$gam_iniciador_dest_dir" "$gam_iniciador_cfg_dest"    "gam7 iniciador cfg"
      materialize "$gam_iniciador_oauth2_src" "$gam_iniciador_dest_dir" "$gam_iniciador_oauth2_dest" "gam7 iniciador oauth2"
      materialize "$gam_iniciador_cs_src"     "$gam_iniciador_dest_dir" "$gam_iniciador_cs_dest"     "gam7 iniciador client_secrets"

      # Parent /app/data/.runtime/gam7 dir owner/perm so dashboard listings
      # see consistent ownership.
      gam_root=${goclaw-data-vol}/.runtime/gam7
      [ -d "$gam_root" ] && chown 1000:1000 "$gam_root" && chmod 0750 "$gam_root"
    '';
  };

  # Replace the dashboard-installed himalaya binary with our oauth2-enabled
  # build (himalaya-oauth2, defined in `let`). Goclaw dashboard's
  # GitHub Binaries entry for himalaya should be removed so its verifier
  # does not reconcile our binary back to the upstream tar; this service
  # is then the sole source of truth. Idempotent on the binary's sha and
  # re-runs whenever the derivation store path changes.
  systemd.services.goclaw-himalaya-bin = {
    description = "Install oauth2-enabled himalaya into goclaw shared volume";
    after = [ "goclaw.service" ];
    wants = [ "goclaw.service" ];
    wantedBy = [ "multi-user.target" ];

    restartTriggers = [ himalaya-oauth2 ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    path = [
      pkgs.coreutils
    ];

    script = ''
      set -euo pipefail

      bin=${goclaw-data-vol}/.runtime/bin/himalaya
      src=${himalaya-oauth2}/bin/himalaya

      for _ in $(seq 1 60); do
        [ -d "${goclaw-data-vol}/.runtime/bin" ] && break
        sleep 2
      done
      if [ ! -d "${goclaw-data-vol}/.runtime/bin" ]; then
        echo ".runtime/bin not present yet; nothing to do"
        exit 0
      fi

      desired=$(sha256sum "$src" | cut -d' ' -f1)
      current=""
      [ -f "$bin" ] && current=$(sha256sum "$bin" | cut -d' ' -f1)
      if [ "$desired" != "$current" ]; then
        install -m 0755 -o 1000 -g 1000 "$src" "$bin"
        echo "himalaya replaced with oauth2-enabled build (sha=$desired)"
      else
        echo "himalaya already at oauth2-enabled build"
      fi
    '';
  };

  # Install gam7 (GAM-team/GAM) into the shared volume. The pip "gam"
  # package on PyPI ships no binary, so the dashboard's Pip Packages
  # flow leaves /app/data/.runtime/bin/gam absent. Fetch the upstream
  # PyInstaller-frozen tarball ("legacy" target = oldest glibc, runs
  # under gcompat in our Alpine sandbox) and drop a small wrapper at
  # /app/data/.runtime/bin/gam that execs the real binary so PATH
  # resolution picks it up. Idempotent on the pinned tar sha.
  systemd.services.goclaw-gam-bin = {
    description = "Install gam7 (GAM-team/GAM) binary into goclaw shared volume";
    after = [ "goclaw.service" ];
    wants = [ "goclaw.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    path = [
      pkgs.curl
      pkgs.coreutils
      pkgs.gnutar
      pkgs.xz
    ];

    script = ''
      set -euo pipefail

      gam_dir=${goclaw-data-vol}/.runtime/gam
      gam_real=$gam_dir/gam
      gam_wrap=${goclaw-data-vol}/.runtime/bin/gam
      target_sha="${goclaw-gam-tar-sha256}"

      for _ in $(seq 1 60); do
        [ -d "${goclaw-data-vol}/.runtime/bin" ] && break
        sleep 2
      done
      if [ ! -d "${goclaw-data-vol}/.runtime/bin" ]; then
        echo ".runtime/bin not present yet; nothing to do"
        exit 0
      fi

      current_sha=""
      [ -f "$gam_dir/.installed-sha" ] && current_sha=$(cat "$gam_dir/.installed-sha")
      if [ "$current_sha" != "$target_sha" ]; then
        echo "Installing gam7 ${goclaw-gam-version} (current sha: ''${current_sha:-none})..."
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        curl -fsSL "${goclaw-gam-url}" -o "$tmp/gam.tar.xz"
        echo "$target_sha  $tmp/gam.tar.xz" | sha256sum -c -
        rm -rf "$gam_dir"
        mkdir -p "$gam_dir"
        tar -xJf "$tmp/gam.tar.xz" -C "$gam_dir" --strip-components=1
        echo "$target_sha" > "$gam_dir/.installed-sha"
        chown -R 1000:1000 "$gam_dir"
        echo "gam7 installed at $gam_real"
      else
        echo "gam7 already at ${goclaw-gam-version}"
      fi

      # Defensive cleanup: legacy (staticx) variant ships only the
      # monolithic gam binary, no vendored lib/. If a previous deploy
      # left a glibc2.35-style lib/ directory behind, remove its
      # libz.so.1 so the dynamic loader doesn't resolve to it after
      # we switch tar layouts.
      rm -f "$gam_dir/lib/libz.so.1" 2>/dev/null || true

      # Wrapper at /app/data/.runtime/bin/gam. gam7 demands read+write
      # access to oauth2service.json + oauth2.txt and writable cache
      # dirs, but the agenix-materialized config + SA JSON live on
      # /app/data which is mounted read-only in the sandbox. The
      # wrapper copies both files into /tmp/gam7/iniciador (tmpfs,
      # writable) on every invocation, mkdirs the cache + drive
      # scratch dirs, and points gam at the writable copy via
      # GAMCFGDIR. State is ephemeral per sandbox spawn — fits gam's
      # service-account flow which mints JWTs per call without
      # needing persistent oauth2.txt across runs.
      wrap_content='#!/bin/sh
src=/app/data/.runtime/gam7/iniciador
dst=/tmp/gam7/iniciador
mkdir -p "$dst" /tmp/gam7/cache /tmp/gam7/drive
cp -f "$src/gam.cfg" "$dst/gam.cfg"
cp -f "$src/oauth2service.json" "$dst/oauth2service.json"
chmod 0600 "$dst/oauth2service.json"
if [ -f "$src/oauth2.txt" ]; then
  cp -f "$src/oauth2.txt" "$dst/oauth2.txt"
  chmod 0600 "$dst/oauth2.txt"
fi
if [ -f "$src/client_secrets.json" ]; then
  cp -f "$src/client_secrets.json" "$dst/client_secrets.json"
  chmod 0600 "$dst/client_secrets.json"
fi
export GAMCFGDIR="$dst"
exec /app/data/.runtime/gam/gam "$@"'
      desired_sha=$(printf '%s\n' "$wrap_content" | sha256sum | cut -d' ' -f1)
      current_wrap_sha=""
      [ -f "$gam_wrap" ] && current_wrap_sha=$(sha256sum "$gam_wrap" | cut -d' ' -f1)
      if [ "$desired_sha" != "$current_wrap_sha" ]; then
        printf '%s\n' "$wrap_content" > "$gam_wrap.new"
        chmod 0755 "$gam_wrap.new"
        chown 1000:1000 "$gam_wrap.new"
        mv "$gam_wrap.new" "$gam_wrap"
        echo "gam wrapper updated"
      else
        echo "gam wrapper already up to date"
      fi
    '';
  };

  # gcalcli per-tenant install. gcalcli (pip-installed by the dashboard
  # into /app/data/.runtime/pip) has no native multi-account support,
  # so we ship two wrappers — gcalcli-hadenes / gcalcli-iniciador —
  # that point gcalcli at a per-tenant config folder via
  # --config-folder. The agenix-encrypted oauth credential files live
  # in /app/data/.runtime/gcalcli/<tenant>/oauth (read-only) and the
  # wrappers copy them to /tmp/gcalcli/<tenant>/oauth so gcalcli can
  # rotate the cached access_token (refresh_token stays the same).
  systemd.services.goclaw-gcalcli-bin = {
    description = "Install gcalcli per-tenant wrappers + oauth credentials";
    after = [
      "goclaw.service"
      "agenix.service"
    ];
    wants = [
      "goclaw.service"
      "agenix.service"
    ];
    wantedBy = [ "multi-user.target" ];

    restartTriggers = [
      config.age.secrets."goclaw-gcalcli-hadenes-oauth".file
      config.age.secrets."goclaw-gcalcli-iniciador-oauth".file
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    path = [
      pkgs.coreutils
    ];

    script = ''
      set -euo pipefail

      vol_dir=${goclaw-data-vol}/.runtime/gcalcli
      bin_dir=${goclaw-data-vol}/.runtime/bin

      for _ in $(seq 1 60); do
        [ -d "$bin_dir" ] && break
        sleep 2
      done
      if [ ! -d "$bin_dir" ]; then
        echo ".runtime/bin not present yet; nothing to do"
        exit 0
      fi

      mkdir -p "$vol_dir"
      chown 1000:1000 "$vol_dir"
      chmod 0750 "$vol_dir"

      materialize_oauth() {
        tenant=$1; src=$2
        dst_dir="$vol_dir/$tenant"
        dst="$dst_dir/oauth"
        if [ ! -s "$src" ]; then
          echo "agenix secret $src missing or empty; skipping gcalcli $tenant"
          return 0
        fi
        mkdir -p "$dst_dir"
        chown 1000:1000 "$dst_dir"
        chmod 0750 "$dst_dir"
        desired=$(sha256sum "$src" | cut -d' ' -f1)
        current=""
        [ -f "$dst" ] && current=$(sha256sum "$dst" | cut -d' ' -f1)
        if [ "$desired" != "$current" ]; then
          install -m 0600 -o 1000 -g 1000 "$src" "$dst"
          echo "gcalcli $tenant oauth materialized"
        else
          echo "gcalcli $tenant oauth already up to date"
        fi
      }

      materialize_oauth "hadenes"   ${config.age.secrets."goclaw-gcalcli-hadenes-oauth".path}
      materialize_oauth "iniciador" ${config.age.secrets."goclaw-gcalcli-iniciador-oauth".path}

      install_wrapper() {
        tenant=$1
        wrap_path="$bin_dir/gcalcli-$tenant"
        # gcalcli ignores --config-folder for oauth storage; it always
        # uses platformdirs.user_data_path('gcalcli'), which on Linux
        # resolves to \$HOME/.local/share/gcalcli/oauth. Override HOME
        # to a per-tenant /tmp dir so the two wrappers don't fight over
        # the same on-disk oauth file. Materialized read-only oauth
        # from the volume is copied into the per-tenant data dir on
        # each invocation; gcalcli rotates the cached access_token in
        # place there (refresh_token stays).
        wrap_content="#!/bin/sh
home=/tmp/gcalcli-$tenant
data_dir=\$home/.local/share/gcalcli
mkdir -p \"\$data_dir\"
cp -f /app/data/.runtime/gcalcli/$tenant/oauth \"\$data_dir/oauth\"
chmod 0600 \"\$data_dir/oauth\"
export HOME=\"\$home\"
exec python3 -m gcalcli.cli \"\$@\""
        desired=$(printf '%s\n' "$wrap_content" | sha256sum | cut -d' ' -f1)
        current=""
        [ -f "$wrap_path" ] && current=$(sha256sum "$wrap_path" | cut -d' ' -f1)
        if [ "$desired" != "$current" ]; then
          printf '%s\n' "$wrap_content" > "$wrap_path.new"
          chmod 0755 "$wrap_path.new"
          chown 1000:1000 "$wrap_path.new"
          mv "$wrap_path.new" "$wrap_path"
          echo "gcalcli-$tenant wrapper updated"
        else
          echo "gcalcli-$tenant wrapper already up to date"
        fi
      }

      install_wrapper hadenes
      install_wrapper iniciador
    '';
  };

  # Data directory (compose volumes live under /var/lib/docker)
  systemd.tmpfiles.rules = [
    "d ${goclaw-home} 0750 goclaw goclaw -"
    # Persistent OAuth credential store for google_workspace_mcp; bind-mounted
    # into the goclaw container at /app/.google_workspace_mcp.
    "d ${goclaw-home}/mcp-creds 0750 goclaw goclaw -"
    "d ${goclaw-mcp-creds-host} 0750 goclaw goclaw -"
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
