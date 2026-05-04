# Machine configuration for stremio LXC
# Stremio Server (https://github.com/Stremio/server-docker)
#
# Single Docker container behind nginx with Let's Encrypt + Cloudflare DNS-01.
# Container ships its own ffmpeg/ffprobe (jellyfin-ffmpeg) so no host bind
# mounts are needed; CPU-only transcoding (no GPU on this host).
#
# Endpoints:
#   https://stremio.hyades.io/  → server JSON-RPC (transcoding, casting)
#
# First-deploy workflow (after creating the LXC on Proxmox):
#   1. Capture LXC SSH host pubkey: `ssh root@<stremio-ip> cat /nix/persist/etc/ssh/ssh_host_ed25519_key.pub`
#   2. Add the pubkey as `stremioKey` to:
#        - private/nixos/secrets/cloudflare/secrets.nix (cloudflare-dns-token recipients)
#        - private/nixos/secrets/lxc-management/secrets.nix (lxc-management.pem recipients)
#   3. Re-encrypt: `cd private/nixos/secrets/<dir> && agenix -r` for each touched dir
#   4. Add Cloudflare DNS A record for stremio.hyades.io → LXC IP
#   5. `rebuild -vL stremio` (or `ssh aether '...' nh os switch`)
{ config, lib, pkgs, private, ... }:

let
  # Inline mkEmail (mirrors shared/helpers.nix). Avoids importing the full
  # helpers module from a NixOS LXC context.
  mkEmail = user: domain: "${user}@${domain}";
in
{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # Cloudflare DNS token for ACME DNS-01 challenges (global secret)
  age.secrets."cloudflare-dns-token" = {
    file = "${private}/nixos/secrets/cloudflare/cloudflare-dns-token.age";
  };

  # ACME (Let's Encrypt) with Cloudflare DNS-01 challenge
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = mkEmail "kamus" "hadenes.io";
      dnsProvider = "cloudflare";
      environmentFile = config.age.secrets."cloudflare-dns-token".path;
    };
    certs."stremio.hyades.io" = { };
  };

  # Allow nginx to read ACME certs
  users.users.nginx.extraGroups = [ "acme" ];

  # Nginx reverse proxy: HTTPS → stremio container on 127.0.0.1:11470
  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedProxySettings = true;
    virtualHosts."stremio.hyades.io" = {
      forceSSL = true;
      useACMEHost = "stremio.hyades.io";
      locations."/" = {
        proxyPass = "http://127.0.0.1:11470";
        # Stremio streams may be large; bump timeouts and allow long-lived
        # connections for casting.
        extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 1h;
          proxy_send_timeout 1h;
          client_max_body_size 0;
        '';
      };
    };
  };

  # Enable Docker for stremio container
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # Stremio container — bind to localhost; nginx fronts external traffic
  virtualisation.oci-containers = {
    backend = "docker";
    containers.stremio = {
      image = "stremio/server:latest";
      autoStart = true;
      ports = [ "127.0.0.1:11470:11470" ];
      extraOptions = [ "--dns=10.23.23.1" "--dns=1.1.1.1" ];
      volumes = [
        "/var/lib/stremio:/root/.stremio-server"
      ];
      environment = {
        NO_CORS = "1";
      };
    };
  };

  # Ensure data directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/stremio 0700 root root -"
  ];

  # Open firewall for HTTPS (nginx)
  networking.firewall.allowedTCPPorts = [ 443 ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;
}
