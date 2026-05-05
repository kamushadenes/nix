# Machine configuration for media LXC
# Privileged Proxmox LXC running the *arr stack, downloaders, Jellyfin,
# Zilean+Postgres, Profilarr, and Caddy reverse proxy with wildcard
# *.hyades.io cert (Cloudflare DNS-01).
#
# Plan: .omc/plans/media-stack.md (consensus iteration 3, APPROVED)
#
# First-deploy workflow (after creating LXC on Proxmox):
#   1. Capture LXC SSH host pubkey:
#        ssh root@10.23.23.60 cat /nix/persist/etc/ssh/ssh_host_ed25519_key.pub
#   2. Add the pubkey as `mediaKey` to:
#        - private/nixos/secrets/media/secrets.nix (uncomment placeholder)
#        - private/nixos/secrets/cloudflare/secrets.nix (cloudflare-dns-token recipients)
#        - private/nixos/secrets/lxc-management/secrets.nix (lxc-management.pem recipients)
#   3. Re-encrypt: `cd private/nixos/secrets/<dir> && agenix -r` for each touched dir
#   4. `rebuild -vL media` (or `ssh aether '...' nh os switch`)
{ config, lib, pkgs, private, ... }:

let
  mkEmail = user: domain: "${user}@${domain}";
  mediaUid = 1000;
  mediaGid = 1000;
  # TrueNAS NFS server (literal IP — `truenas.hyades.io` resolves to
  # Cloudflare publicly which would not serve NFS; pve1 has /etc/hosts entry,
  # but new LXCs use 10.23.23.1 DNS only).
  truenasIp = "10.23.23.14";
  nfsExport = "/mnt/HDD/Media";
  storageRoot = "/storage";
  mediaNet = "media";

  containerNames = [
    "prowlarr" "sonarr" "radarr" "bazarr" "jellyseerr"
    "decypharr" "zilean-postgres" "zilean"
    "jellyfin" "profilarr" "posterizarr"
  ];

  baseExtraOpts = [ "--network=${mediaNet}" ];
  arrEnv = {
    PUID = toString mediaUid;
    PGID = toString mediaGid;
    TZ = "America/Sao_Paulo";
  };
  arrVolumes = [
    "/storage:/storage:rshared"
    "/mnt/realdebrid:/mnt/realdebrid:rshared"
    "/mnt/decypharr-dl:/mnt/decypharr-dl:rshared"
  ];
in
{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  age.secrets = {
    "cloudflare-dns-token".file = "${private}/nixos/secrets/cloudflare/cloudflare-dns-token.age";
    "realdebrid-api-key" = {
      file = "${private}/nixos/secrets/media/realdebrid-api-key.age";
      path = "/run/agenix/realdebrid-api-key";
      mode = "0400";
    };
    "usenet-eweka" = {
      file = "${private}/nixos/secrets/media/usenet-eweka.age";
      path = "/run/agenix/usenet-eweka";
      mode = "0400";
    };
    "usenet-newshosting" = {
      file = "${private}/nixos/secrets/media/usenet-newshosting.age";
      path = "/run/agenix/usenet-newshosting";
      mode = "0400";
    };
    "usenet-easynews" = {
      file = "${private}/nixos/secrets/media/usenet-easynews.age";
      path = "/run/agenix/usenet-easynews";
      mode = "0400";
    };
    "nzbgeek-api" = {
      file = "${private}/nixos/secrets/media/nzbgeek-api.age";
      path = "/run/agenix/nzbgeek-api";
      mode = "0400";
    };
    "nzbfinder-api" = {
      file = "${private}/nixos/secrets/media/nzbfinder-api.age";
      path = "/run/agenix/nzbfinder-api";
      mode = "0400";
    };
    "postgres-zilean" = {
      file = "${private}/nixos/secrets/media/postgres-zilean.age";
      path = "/run/agenix/postgres-zilean";
      mode = "0400";
    };
    "decypharr-env" = {
      file = "${private}/nixos/secrets/media/decypharr-env.age";
      path = "/run/agenix/decypharr-env";
      mode = "0400";
    };
  };

  # ACME ownership decision: SINGLE runner — NixOS `security.acme` (lego)
  # owns the wildcard `*.hyades.io` cert via Cloudflare DNS-01. Caddy
  # consumes the issued cert via explicit `tls <fullchain> <key>` directive
  # in each vhost. Renewal -> Caddy reload coupling: `reloadServices = [
  # "caddy.service" ]` on the cert.
  #
  # Why not Caddy-native ACME plugin: pkgs.caddy.withPlugins requires building
  # Caddy from source against a Go toolchain that nixpkgs (both 25.11 and
  # unstable as of 2026-05) lags behind, so the build fails with
  # "go.mod requires go >= X.Y.Z (running go X.Y.Y)". NixOS security.acme is
  # already in production for aiostreams.nix and works.
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = mkEmail "kamus" "hadenes.io";
      dnsProvider = "cloudflare";
      environmentFile = config.age.secrets."cloudflare-dns-token".path;
    };
    certs."hyades.io" = {
      domain = "hyades.io";
      extraDomainNames = [ "*.hyades.io" ];
      reloadServices = [ "caddy.service" ];
    };
  };

  # NFS mount — eager, _netdev, nofail; Docker waits for it explicitly.
  services.rpcbind.enable = true;
  fileSystems."${storageRoot}" = {
    device = "${truenasIp}:${nfsExport}";
    fsType = "nfs4";
    options = [
      "nfsvers=4.2"
      "hard"
      "rsize=1048576"
      "wsize=1048576"
      "noatime"
      "_netdev"
      "nofail"
      "x-systemd.mount-timeout=30"
    ];
  };

  # Caddy reads the wildcard cert issued by NixOS security.acme above.
  services.caddy = {
    enable = true;
    globalConfig = ''
      auto_https disable_redirects
    '';
    virtualHosts =
      let
        certDir = "/var/lib/acme/hyades.io";
        mkProxy = port: ''
          tls ${certDir}/fullchain.pem ${certDir}/key.pem
          reverse_proxy 127.0.0.1:${toString port}
        '';
      in {
        "jellyfin.hyades.io".extraConfig    = mkProxy 8096;
        "jellyseerr.hyades.io".extraConfig  = mkProxy 5055;
        "sonarr.hyades.io".extraConfig      = mkProxy 8989;
        "radarr.hyades.io".extraConfig      = mkProxy 7878;
        "prowlarr.hyades.io".extraConfig    = mkProxy 9696;
        "bazarr.hyades.io".extraConfig      = mkProxy 6767;
        "decypharr.hyades.io".extraConfig   = mkProxy 8282;
        "profilarr.hyades.io".extraConfig   = mkProxy 6868;
        "zilean.hyades.io".extraConfig      = mkProxy 8182;
        "posterizarr.hyades.io".extraConfig = mkProxy 8484;
      };
  };

  users.users.caddy.extraGroups = [ "acme" ];

  # Docker daemon
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    daemon.settings = {
      log-driver = "json-file";
      log-opts = { max-size = "10m"; max-file = "3"; };
    };
  };

  # All systemd.services definitions merged into a single attribute to avoid
  # NixOS module-system "attribute already defined" conflicts. Order:
  #   1. make-rshared-mounts: host-side mount --make-rshared on /storage and
  #      /mnt/decypharr-dl before docker.service. Idempotent.
  #   2. caddy: EnvironmentFile = caddy-cloudflare-token (Caddy native ACME
  #      DNS-01 plugin reads CF_API_TOKEN from this).
  #   3. docker-network-media: create the user-defined `media` Docker network
  #      so containers resolve each other by name.
  #   4. docker-${name} (every oci-container): after=docker-network-media.service.
  #   5. docker-zilean: also after=docker-zilean-postgres.service.
  systemd.services = lib.mkMerge [
    {
      make-rshared-mounts = {
        # /mnt/realdebrid is intentionally NOT pre-bound here: rclone-decypharr-mount
        # creates its own FUSE mount there and sets rshared in its ExecStartPost.
        description = "Make /storage, /mnt/decypharr-dl rshared";
        wantedBy = [ "docker.service" ];
        before = [ "docker.service" ];
        after = [ "storage.mount" "local-fs.target" ];
        unitConfig = {
          RequiresMountsFor = [ "/storage" "/mnt/decypharr-dl" ];
        };
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "make-rshared" ''
            set -euo pipefail
            ${pkgs.util-linux}/bin/findmnt -no PROPAGATION /storage | grep -q shared || \
              ${pkgs.util-linux}/bin/mount --make-rshared /storage
            for dir in /mnt/decypharr-dl; do
              ${pkgs.util-linux}/bin/mountpoint -q "$dir" || \
                ${pkgs.util-linux}/bin/mount --bind "$dir" "$dir"
              ${pkgs.util-linux}/bin/findmnt -no PROPAGATION "$dir" | grep -q shared || \
                ${pkgs.util-linux}/bin/mount --make-rshared "$dir"
            done
          '';
        };
      };

      docker-network-media = {
        description = "Create media docker network";
        wantedBy = [ "multi-user.target" ];
        after = [ "docker.service" ];
        requires = [ "docker.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "docker-network-media-create" ''
            ${pkgs.docker}/bin/docker network inspect ${mediaNet} >/dev/null 2>&1 || \
              ${pkgs.docker}/bin/docker network create --driver bridge ${mediaNet}
          '';
          ExecStop = pkgs.writeShellScript "docker-network-media-stop" ''
            ${pkgs.docker}/bin/docker network rm ${mediaNet} || true
          '';
        };
      };
    }
    (lib.genAttrs (map (n: "docker-${n}") containerNames) (_: {
      after = [ "docker-network-media.service" ];
      requires = [ "docker-network-media.service" ];
    }))
    {
      "docker-zilean" = {
        after = [ "docker-zilean-postgres.service" "docker-network-media.service" ];
        requires = [ "docker-zilean-postgres.service" "docker-network-media.service" ];
      };
    }
    # Decypharr no longer manages the FUSE mount itself — rclone runs on the
    # LXC host (rclone-decypharr-mount.service) and mounts Decypharr's WebDAV
    # at /mnt/realdebrid. *arrs and jellyfin must wait for that mount to exist
    # before they start, otherwise their :rshared bind sees an empty directory.
    # rclone in turn waits for docker-decypharr (so the WebDAV endpoint is up).
    {
      "rclone-decypharr-mount" = {
        description = "rclone WebDAV mount of Decypharr → /mnt/realdebrid";
        after = [ "docker-decypharr.service" ];
        requires = [ "docker-decypharr.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.rclone pkgs.curl pkgs.fuse ];
        serviceConfig = {
          Type = "exec";
          Restart = "on-failure";
          RestartSec = "5s";
          ExecStartPre = pkgs.writeShellScript "rclone-decypharr-wait" ''
            set -euo pipefail
            for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
              if ${pkgs.curl}/bin/curl -fsS -o /dev/null --max-time 2 http://127.0.0.1:8282/; then
                exit 0
              fi
              ${pkgs.coreutils}/bin/sleep 1
            done
            echo "Decypharr WebDAV did not come up within 60s" >&2
            exit 1
          '';
          ExecStart = pkgs.writeShellScript "rclone-decypharr-mount" ''
            exec ${pkgs.rclone}/bin/rclone mount decypharr: /mnt/realdebrid \
              --config=/etc/rclone-decypharr/rclone.conf \
              --cache-dir=/var/cache/rclone-decypharr \
              --allow-other \
              --uid=1000 --gid=1000 --umask=022 \
              --dir-cache-time=10s --poll-interval=10s \
              --vfs-cache-mode=full --vfs-cache-max-size=32G --vfs-cache-max-age=72h \
              --vfs-read-chunk-size=64M --vfs-read-chunk-size-limit=2G \
              --vfs-read-ahead=256M \
              --buffer-size=64M --transfers=16 \
              --rc --rc-addr=0.0.0.0:5572 --rc-no-auth \
              --log-level=INFO
          '';
          ExecStartPost = pkgs.writeShellScript "rclone-decypharr-mount-rshared" ''
            set -euo pipefail
            for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
              if ${pkgs.util-linux}/bin/mountpoint -q /mnt/realdebrid; then
                ${pkgs.util-linux}/bin/mount --make-rshared /mnt/realdebrid
                exit 0
              fi
              ${pkgs.coreutils}/bin/sleep 1
            done
            echo "rclone mount did not appear within 30s" >&2
            exit 1
          '';
          ExecStop = "${pkgs.fuse}/bin/fusermount -uz /mnt/realdebrid";
        };
      };
      "docker-radarr" = {
        after = [ "rclone-decypharr-mount.service" "docker-network-media.service" ];
        requires = [ "rclone-decypharr-mount.service" ];
      };
      "docker-sonarr" = {
        after = [ "rclone-decypharr-mount.service" "docker-network-media.service" ];
        requires = [ "rclone-decypharr-mount.service" ];
      };
      "docker-bazarr" = {
        after = [ "rclone-decypharr-mount.service" "docker-network-media.service" ];
        requires = [ "rclone-decypharr-mount.service" ];
      };
      "docker-jellyfin" = {
        after = [ "rclone-decypharr-mount.service" "docker-network-media.service" ];
        requires = [ "rclone-decypharr-mount.service" ];
      };
    }
  ];

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      prowlarr = {
        image = "lscr.io/linuxserver/prowlarr:2.3.5";
        autoStart = true;
        ports = [ "127.0.0.1:9696:9696" ];
        environment = arrEnv;
        volumes = [ "/var/lib/media/prowlarr:/config" ];
        extraOptions = baseExtraOpts ++ [ "--memory=512m" "--cpus=1.0" ];
      };
      sonarr = {
        image = "lscr.io/linuxserver/sonarr:4.0.17";
        autoStart = true;
        ports = [ "127.0.0.1:8989:8989" ];
        environment = arrEnv;
        volumes = [ "/var/lib/media/sonarr:/config" ] ++ arrVolumes;
        extraOptions = baseExtraOpts ++ [ "--memory=1g" "--cpus=2.0" ];
      };
      radarr = {
        image = "lscr.io/linuxserver/radarr:6.1.1";
        autoStart = true;
        ports = [ "127.0.0.1:7878:7878" ];
        environment = arrEnv;
        volumes = [ "/var/lib/media/radarr:/config" ] ++ arrVolumes;
        extraOptions = baseExtraOpts ++ [ "--memory=1g" "--cpus=2.0" ];
      };
      bazarr = {
        image = "lscr.io/linuxserver/bazarr:1.5.4";
        autoStart = true;
        ports = [ "127.0.0.1:6767:6767" ];
        environment = arrEnv;
        volumes = [ "/var/lib/media/bazarr:/config" ] ++ arrVolumes;
        extraOptions = baseExtraOpts ++ [ "--memory=512m" "--cpus=1.0" ];
      };
      jellyseerr = {
        image = "fallenbagel/jellyseerr:2.5.2";
        autoStart = true;
        ports = [ "127.0.0.1:5055:5055" ];
        environment = { LOG_LEVEL = "info"; TZ = "America/Sao_Paulo"; };
        volumes = [ "/var/lib/media/jellyseerr:/app/config" ];
        extraOptions = baseExtraOpts ++ [ "--memory=512m" "--cpus=1.0" ];
      };
      decypharr = {
        # external_rclone mode: rclone runs on the LXC host
        # (rclone-decypharr-mount.service) and mounts Decypharr's WebDAV
        # at /mnt/realdebrid. Decypharr only serves WebDAV + writes symlinks
        # in /mnt/decypharr-dl, so no FUSE access needed inside the container.
        image = "ghcr.io/sirrobot01/decypharr:v2.2";
        autoStart = true;
        ports = [ "127.0.0.1:8282:8282" ];
        environmentFiles = [
          "/run/agenix/realdebrid-api-key"
          "/run/agenix/decypharr-env"
        ];
        volumes = [
          "/var/lib/media/decypharr:/app"
          "/mnt/decypharr-dl:/mnt/decypharr-dl:rshared"
        ];
        extraOptions = baseExtraOpts ++ [
          "--memory=2g"
          "--cpus=2.0"
        ];
      };
      zilean-postgres = {
        image = "postgres:16.6";
        autoStart = true;
        environment = { POSTGRES_USER = "zilean"; POSTGRES_DB = "zilean"; };
        environmentFiles = [ "/run/agenix/postgres-zilean" ];
        volumes = [ "/var/lib/media/zilean-pg:/var/lib/postgresql/data" ];
        extraOptions = baseExtraOpts ++ [ "--memory=2g" "--cpus=1.0" ];
      };
      zilean = {
        image = "ipromknight/zilean:3.5.0";
        autoStart = true;
        ports = [ "127.0.0.1:8182:8182" ];
        environment = { Zilean__Server__Port = "8182"; };
        # ZILEAN_DB_CONN comes from the env file (no Nix-string interpolation
        # of $POSTGRES_PASSWORD — Docker `environment{}` strings are not
        # shell-expanded).
        environmentFiles = [ "/run/agenix/postgres-zilean" ];
        extraOptions = baseExtraOpts ++ [ "--memory=2g" "--cpus=2.0" ];
      };
      jellyfin = {
        image = "jellyfin/jellyfin:10.10.7";
        autoStart = true;
        ports = [ "127.0.0.1:8096:8096" ];
        environment = { TZ = "America/Sao_Paulo"; };
        volumes = [
          "/var/lib/media/jellyfin/config:/config"
          "/var/lib/media/jellyfin/cache:/cache"
          "/storage:/storage:ro"
          "/mnt/realdebrid:/mnt/realdebrid:rshared"
          "/mnt/decypharr-dl:/mnt/decypharr-dl:rshared"
        ];
        extraOptions = baseExtraOpts ++ [ "--memory=4g" "--cpus=4.0" ];
        # /dev/dri NOT mounted — HW transcode is phase 2.
      };
      profilarr = {
        image = "santiagosayshey/profilarr:v1.1.4";
        autoStart = true;
        ports = [ "127.0.0.1:6868:6868" ];
        volumes = [ "/var/lib/media/profilarr:/config" ];
        extraOptions = baseExtraOpts ++ [ "--memory=512m" "--cpus=1.0" ];
      };
      # Posterizarr — fetches custom posters from TPDB / Fanart / TMDb / TVDb
      # and applies via Jellyfin API. Runs scheduled scans (cron-driven inside
      # container). Config + assets persist in /var/lib/media/posterizarr.
      posterizarr = {
        image = "ghcr.io/fscorrupt/posterizarr:2.2.40";
        autoStart = true;
        ports = [ "127.0.0.1:8484:8000" ];
        environment = { TZ = "America/Sao_Paulo"; };
        volumes = [
          "/var/lib/media/posterizarr:/config"
          "/var/lib/media/posterizarr/assets:/assets"
        ];
        extraOptions = baseExtraOpts ++ [
          "--user=1000:1000"
          "--memory=1g"
          "--cpus=1.0"
        ];
      };
    };
  };

  # Persistence dirs. UID 1000:1000 explicit; postgres 999:999.
  systemd.tmpfiles.rules = [
    "d /var/lib/media 0755 1000 1000 -"
    "d /var/lib/media/prowlarr 0755 1000 1000 -"
    "d /var/lib/media/sonarr 0755 1000 1000 -"
    "d /var/lib/media/radarr 0755 1000 1000 -"
    "d /var/lib/media/bazarr 0755 1000 1000 -"
    "d /var/lib/media/jellyseerr 0755 1000 1000 -"
    "d /var/lib/media/decypharr 0755 1000 1000 -"
    "d /var/lib/media/zilean-pg 0700 999 999 -"
    "d /var/lib/media/jellyfin 0755 1000 1000 -"
    "d /var/lib/media/jellyfin/config 0755 1000 1000 -"
    "d /var/lib/media/jellyfin/cache 0755 1000 1000 -"
    "d /var/lib/media/profilarr 0755 1000 1000 -"
    "d /var/lib/media/posterizarr 0755 1000 1000 -"
    "d /var/lib/media/posterizarr/assets 0755 1000 1000 -"
    "d /mnt/realdebrid 0755 1000 1000 -"
    "d /mnt/decypharr-dl 0755 1000 1000 -"
    "d /var/cache/rclone-decypharr 0755 root root -"
  ];

  # rclone WebDAV remote pointing at Decypharr's built-in WebDAV server.
  # Decypharr runs with use_auth=false (LAN-only behind Caddy + Tailscale),
  # so no credentials are required. The mount is consumed by
  # rclone-decypharr-mount.service.
  environment.etc."rclone-decypharr/rclone.conf".text = ''
    [decypharr]
    type = webdav
    url = http://127.0.0.1:8282/webdav
    vendor = other
  '';

  networking.firewall.allowedTCPPorts = [ 443 ];
  networking.networkmanager.enable = lib.mkForce false;

  # role="headless" pulls in security.nix which sets PermitRootLogin = "no".
  # Override to allow root key auth (mirrors goclaw.nix:1366 pattern).
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";

  # promote-movie: convert a streamed Decypharr symlink into a real on-disk
  # file so seeking is instant. Reads bytes through the FUSE mount, atomically
  # swaps the symlink for the materialized file, then triggers a Radarr rescan
  # so metadata stays in sync.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "promote-movie" ''
      set -euo pipefail
      if [ $# -lt 1 ]; then
        echo "usage: promote-movie <path-or-title>" >&2
        exit 1
      fi
      input="$1"
      if [ -e "$input" ]; then
        target="$input"
      else
        target=$(${pkgs.findutils}/bin/find /storage -maxdepth 4 \( -iname "*$input*.mkv" -o -iname "*$input*.mp4" -o -iname "*$input*.m4v" \) 2>/dev/null | ${pkgs.coreutils}/bin/head -1 || true)
        if [ -z "$target" ]; then
          echo "no file found matching: $input" >&2
          exit 1
        fi
        echo "found: $target"
      fi
      if [ ! -L "$target" ] && [ -f "$target" ]; then
        echo "already a real file, nothing to promote"
        exit 0
      fi
      src=$(${pkgs.coreutils}/bin/readlink -f "$target")
      size=$(${pkgs.coreutils}/bin/stat -c %s "$src" 2>/dev/null || echo 0)
      echo "size: $(${pkgs.coreutils}/bin/numfmt --to=iec --suffix=B "$size")"
      echo "promoting: $target"
      echo "from:      $src"
      tmp="$target.promote.tmp"
      ${pkgs.coreutils}/bin/cp -L "$target" "$tmp"
      ${pkgs.coreutils}/bin/mv "$tmp" "$target"
      echo "done — file is now real on disk"
      key=$(${pkgs.gnugrep}/bin/grep -oP "(?<=<ApiKey>)[^<]+" /var/lib/media/radarr/config.xml 2>/dev/null || true)
      if [ -n "$key" ]; then
        echo "triggering Radarr rescan…"
        ${pkgs.curl}/bin/curl -fsS -X POST -H "X-Api-Key: $key" -H "Content-Type: application/json" \
          "http://localhost:7878/api/v3/command" -d "{\"name\":\"RescanMovie\"}" >/dev/null && echo "rescan queued"
      fi
    '')
  ];
}
