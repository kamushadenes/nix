# Machine configuration for ccflare LXC
# better-ccflare - Claude API proxy with intelligent load balancing
# https://github.com/tombii/better-ccflare
{ config, lib, pkgs, private, ... }:
let
  ccflareSrc = pkgs.fetchFromGitHub {
    owner = "tombii";
    repo = "better-ccflare";
    rev = "6edd7d34f776501d60c417f4c9d0216d02e5f961";
    hash = "sha256-O9/f5VT9S1W21au8rMIWuiNChDpA4IdTYLDq8X5Oqj0=";
  };

  # Inject generated bun.nix (no source patching needed when running from source)
  ccflareSrcWithBunNix = pkgs.runCommand "ccflare-src" { } ''
    cp -r ${ccflareSrc} $out
    chmod -R u+w $out
    cp ${./resources/ccflare/bun.nix} $out/bun.nix
  '';

  ccflare = pkgs.bun2nix.mkDerivation {
    pname = "better-ccflare";
    version = "3.2.2";
    src = ccflareSrcWithBunNix;

    bunDeps = pkgs.bun2nix.fetchBunDeps {
      bunNix = "${ccflareSrcWithBunNix}/bun.nix";
    };

    # Override default --linker=isolated which breaks workspace package resolution
    # (workspace symlinks aren't created, so cross-package imports fail)
    bunInstallFlags = "--frozen-lockfile";

    # Run from source (compiled binaries crash due to Worker+WASM limitations)
    dontUseBunBuild = true;
    dontUseBunInstall = true;

    buildPhase = ''
      runHook preBuild
      bun run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/ccflare $out/bin
      cp -r . $out/lib/ccflare/

      # Server wrapper
      cat > $out/bin/ccflare-server <<WRAPPER
      #!/usr/bin/env bash
      exec ${pkgs.bun}/bin/bun run $out/lib/ccflare/apps/server/src/server.ts "\$@"
      WRAPPER
      chmod +x $out/bin/ccflare-server

      # CLI wrapper
      cat > $out/bin/ccflare <<WRAPPER
      #!/usr/bin/env bash
      exec ${pkgs.bun}/bin/bun run $out/lib/ccflare/apps/cli/src/main.ts "\$@"
      WRAPPER
      chmod +x $out/bin/ccflare

      # Aliases
      ln -s ccflare-server $out/bin/server
      ln -s ccflare-server $out/bin/start
      ln -s ccflare $out/bin/cli

      runHook postInstall
    '';
  };

  certDir = config.security.acme.certs."ccflare.hyades.io".directory;
  configDir = "/var/lib/ccflare/.config/better-ccflare";
in
{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # Cloudflare DNS API token for ACME DNS-01 challenges
  age.secrets."cloudflare-dns-token" = {
    file = "${private}/nixos/secrets/cloudflare/cloudflare-dns-token.age";
    owner = "acme";
    group = "acme";
  };

  # Let's Encrypt with Cloudflare DNS-01 validation
  security.acme = {
    acceptTerms = true;
    defaults.email = "henrique@kamus.me";
    certs."ccflare.hyades.io" = {
      dnsProvider = "cloudflare";
      environmentFile = config.age.secrets."cloudflare-dns-token".path;
      group = "ccflare";
    };
  };

  # Static user for the service
  users.users.ccflare = {
    isSystemUser = true;
    group = "ccflare";
    home = "/var/lib/ccflare";
    shell = pkgs.bash;
    createHome = true;
  };
  users.groups.ccflare = { };

  # Systemd service for better-ccflare server
  systemd.services.ccflare = {
    description = "better-ccflare - Claude API Proxy";
    after = [ "network-online.target" "acme-ccflare.hyades.io.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "5s";
      User = "ccflare";
      Group = "ccflare";
      StateDirectory = "ccflare";
      StateDirectoryMode = "0700";
      WorkingDirectory = "${ccflare}/lib/ccflare";
      # Symlink ACME certs into the config dir (better-ccflare path validator
      # only allows ~/.config/better-ccflare, cwd, and /tmp)
      ExecStartPre = pkgs.writeShellScript "ccflare-link-certs" ''
        mkdir -p ${configDir}
        ln -sf ${certDir}/key.pem ${configDir}/ssl-key.pem
        ln -sf ${certDir}/fullchain.pem ${configDir}/ssl-cert.pem
      '';
      ExecStart = "${ccflare}/bin/ccflare-server";
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      LimitNOFILE = 65536;
    };

    environment = {
      PORT = "443";
      BETTER_CCFLARE_HOST = "0.0.0.0";
      SSL_KEY_PATH = "${configDir}/ssl-key.pem";
      SSL_CERT_PATH = "${configDir}/ssl-cert.pem";
      LOG_LEVEL = "INFO";
    };
  };

  # Restart ccflare when certs are renewed
  security.acme.certs."ccflare.hyades.io".reloadServices = [ "ccflare.service" ];

  # Ensure data directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/ccflare 0700 ccflare ccflare -"
  ];

  # TCP tuning for high throughput proxy
  # Note: net.core.rmem_max/wmem_max must be set on the Proxmox host (not namespaced)
  boot.kernel.sysctl = {
    "net.core.somaxconn" = 65535;
    "net.ipv4.tcp_max_syn_backlog" = 65535;
    "net.ipv4.tcp_fin_timeout" = 15;
    "net.ipv4.tcp_keepalive_time" = 300;
    "net.ipv4.tcp_keepalive_probes" = 5;
    "net.ipv4.tcp_keepalive_intvl" = 15;
  };

  # Open firewall for HTTPS
  networking.firewall.allowedTCPPorts = [ 443 ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;

  # Add ccflare to system PATH for CLI management
  environment.systemPackages = [ ccflare ];
}
