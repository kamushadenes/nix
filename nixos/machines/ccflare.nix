# Machine configuration for ccflare LXC
# ccflare - Claude API proxy with intelligent load balancing
{ config, lib, pkgs, private, ... }:
let
  ccflareSrc = pkgs.fetchFromGitHub {
    owner = "snipeship";
    repo = "ccflare";
    rev = "688921203f5035e09740ad4f8208d222122d9ea9";
    hash = "sha256-JDrk+BDGMI535JGTwZdf+iYAwHouLi9Yq+cRIxc/3Yk=";
  };

  # Inject generated bun.nix (no source patching needed when running from source)
  ccflareSrcWithBunNix = pkgs.runCommand "ccflare-src" { } ''
    cp -r ${ccflareSrc} $out
    chmod -R u+w $out
    cp ${./resources/ccflare/bun.nix} $out/bun.nix
  '';

  ccflare = pkgs.bun2nix.mkDerivation {
    pname = "ccflare";
    version = "0.1.0";
    src = ccflareSrcWithBunNix;

    bunDeps = pkgs.bun2nix.fetchBunDeps {
      bunNix = "${ccflareSrcWithBunNix}/bun.nix";
    };

    # Override default --linker=isolated which breaks workspace package resolution
    # (workspace symlinks aren't created, so cross-package imports fail)
    bunInstallFlags = "--frozen-lockfile";

    # Run from source (compiled binaries crash due to Worker+WASM limitations)
    # https://github.com/snipeship/ccflare/issues/40
    dontUseBunBuild = true;
    dontUseBunInstall = true;

    buildPhase = ''
      runHook preBuild
      bun run build:dashboard
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

      # TUI wrapper
      cat > $out/bin/ccflare <<WRAPPER
      #!/usr/bin/env bash
      exec ${pkgs.bun}/bin/bun run $out/lib/ccflare/apps/tui/src/main.ts "\$@"
      WRAPPER
      chmod +x $out/bin/ccflare

      # Aliases: server/start -> ccflare-server, tui -> ccflare
      ln -s ccflare-server $out/bin/server
      ln -s ccflare-server $out/bin/start
      ln -s ccflare $out/bin/tui

      runHook postInstall
    '';
  };
in
{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # Static user for the service
  users.users.ccflare = {
    isSystemUser = true;
    group = "ccflare";
    home = "/var/lib/ccflare";
    shell = pkgs.bash;
    createHome = true;
  };
  users.groups.ccflare = { };

  # Systemd service for ccflare server
  systemd.services.ccflare = {
    description = "ccflare - Claude API Proxy";
    after = [ "network-online.target" ];
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
      ExecStart = "${ccflare}/bin/ccflare-server";
      LimitNOFILE = 65536;
    };

    environment = {
      PORT = "8080";
      ccflare_DB_PATH = "/var/lib/ccflare/ccflare.db";
      ccflare_CONFIG_PATH = "/var/lib/ccflare/ccflare.json";
      LOG_LEVEL = "INFO";
    };
  };

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

  # Open firewall for HTTP API + dashboard
  networking.firewall.allowedTCPPorts = [ 8080 ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;

  # Add ccflare to system PATH for CLI management
  environment.systemPackages = [ ccflare ];
}
