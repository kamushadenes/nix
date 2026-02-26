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

  # Inject generated bun.nix into ccflare source (workspace paths resolve relative to bun.nix)
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

    # Compile the server entry point to a standalone binary
    module = "apps/server/src/server.ts";

    # Build the React dashboard before compiling the server
    # (server imports dashboard assets at compile time)
    preBuild = ''
      bun run build:dashboard
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
      WorkingDirectory = "/var/lib/ccflare";
      ExecStart = "${ccflare}/bin/ccflare";
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

  # Open firewall for HTTP API + dashboard
  networking.firewall.allowedTCPPorts = [ 8080 ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;

  # Add ccflare to system PATH for CLI management
  environment.systemPackages = [ ccflare ];
}
