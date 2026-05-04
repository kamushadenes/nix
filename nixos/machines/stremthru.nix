# Machine configuration for stremthru LXC
# StremThru — Stremio addon proxy / RD bridge
# (https://github.com/MunifTanjim/stremthru)
#
# Single Docker container behind Caddy with Let's Encrypt (Cloudflare DNS-01).
# Per-host cert `stremthru.hyades.io` (NOT wildcard — wildcard belongs to
# media LXC; distinct subjects avoid LE duplicate-cert rate-limit.)
#
# Plan: .omc/plans/media-stack.md
#
# First-deploy workflow (after creating LXC on Proxmox):
#   1. Capture LXC SSH host pubkey:
#        ssh root@10.23.23.61 cat /nix/persist/etc/ssh/ssh_host_ed25519_key.pub
#   2. Add the pubkey as `stremthruKey` to:
#        - private/nixos/secrets/stremthru/secrets.nix (uncomment placeholder)
#        - private/nixos/secrets/cloudflare/secrets.nix
#        - private/nixos/secrets/lxc-management/secrets.nix
#   3. Re-encrypt: agenix -r in each touched dir
#   4. `rebuild -vL stremthru`
{ config, lib, pkgs, private, ... }:

{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  age.secrets = {
    "cloudflare-dns-token".file = "${private}/nixos/secrets/cloudflare/cloudflare-dns-token.age";
    "caddy-cloudflare-token" = {
      file = "${private}/nixos/secrets/stremthru/caddy-cloudflare-token.age";
      path = "/run/agenix/caddy-cloudflare-token";
      mode = "0400";
    };
    "stremthru-env" = {
      file = "${private}/nixos/secrets/stremthru/stremthru-env.age";
      path = "/run/agenix/stremthru-env";
      mode = "0400";
    };
  };

  # Caddy native ACME (Cloudflare DNS-01) — per-host cert, NOT wildcard.
  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.1" ];
      hash = "sha256-Pzfdwq6GGUarf9jWpjuHEk3hjhftGZb0SJPqEOErZSg=";
    };
    globalConfig = ''
      auto_https disable_redirects
    '';
    virtualHosts."stremthru.hyades.io".extraConfig = ''
      tls {
        dns cloudflare {env.CF_API_TOKEN}
      }
      reverse_proxy 127.0.0.1:8080
    '';
  };

  systemd.services.caddy = {
    serviceConfig = {
      EnvironmentFile = config.age.secrets."caddy-cloudflare-token".path;
    };
  };

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers.stremthru = {
      image = "muniftanjim/stremthru:0.84.5";
      autoStart = true;
      ports = [ "127.0.0.1:8080:8080" ];
      extraOptions = [ "--dns=10.23.23.1" "--dns=1.1.1.1" ];
      environmentFiles = [ "/run/agenix/stremthru-env" ];
      volumes = [ "/var/lib/stremthru/data:/app/data" ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/stremthru 0755 root root -"
    "d /var/lib/stremthru/data 0700 root root -"
  ];

  networking.firewall.allowedTCPPorts = [ 443 ];
  networking.networkmanager.enable = lib.mkForce false;
}
