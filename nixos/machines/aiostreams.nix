# Machine configuration for aiostreams LXC
# AIOStreams - Stremio addon aggregator (https://docs.aiostreams.viren070.me)
#
# Single Docker container behind nginx with Let's Encrypt + Cloudflare DNS-01.
# Required env (BASE_URL, SECRET_KEY) ships via agenix as aiostreams-env.
# Setup wizard: https://aiostreams.hyades.io/stremio/configure
#
# First-deploy workflow (after creating the LXC on Proxmox):
#   1. Capture LXC SSH host pubkey: `ssh root@<aiostreams-ip> cat /nix/persist/etc/ssh/ssh_host_ed25519_key.pub`
#   2. Add the pubkey as `aiostreamsKey` to:
#        - private/nixos/secrets/aiostreams/secrets.nix (uncomment placeholder)
#        - private/nixos/secrets/cloudflare/secrets.nix (cloudflare-dns-token recipients)
#        - private/nixos/secrets/lxc-management/secrets.nix (lxc-management.pem recipients)
#   3. Re-encrypt: `cd private/nixos/secrets/<dir> && agenix -r` for each touched dir
#   4. Edit aiostreams-env.age in-place (keep existing SECRET_KEY, optionally rotate):
#        `cd private/nixos/secrets/aiostreams && EDITOR=nvim agenix -e aiostreams-env.age`
#   5. Add Cloudflare DNS A record for aiostreams.hyades.io → LXC IP
#   6. `rebuild -vL aiostreams` (or `ssh aether '...' nh os switch`)
{ config, lib, pkgs, private, ... }:

let
  # Inline mkEmail (mirrors shared/helpers.nix). Avoids importing the full
  # helpers module from a NixOS LXC context (it depends on osConfig fields
  # that don't exist on minimal-role hosts).
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

  # AIOStreams runtime env (BASE_URL, SECRET_KEY, optional ADDON_NAME/ID)
  age.secrets."aiostreams-env" = {
    file = "${private}/nixos/secrets/aiostreams/aiostreams-env.age";
    path = "/run/agenix/aiostreams-env";
    mode = "0400";
  };

  # ACME (Let's Encrypt) with Cloudflare DNS-01 challenge
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = mkEmail "kamus" "hadenes.io";
      dnsProvider = "cloudflare";
      environmentFile = config.age.secrets."cloudflare-dns-token".path;
    };
    certs."aiostreams.hyades.io" = { };
  };

  # Allow nginx to read ACME certs
  users.users.nginx.extraGroups = [ "acme" ];

  # Nginx reverse proxy: HTTPS → aiostreams container on 127.0.0.1:3000
  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedProxySettings = true;
    virtualHosts."aiostreams.hyades.io" = {
      forceSSL = true;
      useACMEHost = "aiostreams.hyades.io";
      locations."/" = {
        proxyPass = "http://127.0.0.1:3000";
      };
    };
  };

  # Enable Docker for aiostreams container
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # AIOStreams container — bind to localhost; nginx fronts external traffic
  virtualisation.oci-containers = {
    backend = "docker";
    containers.aiostreams = {
      image = "ghcr.io/viren070/aiostreams:latest";
      autoStart = true;
      ports = [ "127.0.0.1:3000:3000" ];
      extraOptions = [ "--dns=10.23.23.1" "--dns=1.1.1.1" ];
      volumes = [
        "/var/lib/aiostreams/data:/app/data"
      ];
      environmentFiles = [ "/run/agenix/aiostreams-env" ];
      environment = {
        SEL_SYNC_ACCESS = "all";
        REGEX_FILTER_ACCESS = "all";
        MAX_ADDONS = "40";
      };
    };
  };

  # Ensure data directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/aiostreams 0755 root root -"
    "d /var/lib/aiostreams/data 0700 root root -"
  ];

  # Open firewall for HTTPS (nginx)
  networking.firewall.allowedTCPPorts = [ 443 ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;
}
