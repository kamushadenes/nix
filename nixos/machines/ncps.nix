# Machine configuration for ncps LXC
# Nix Cache Proxy Server - local caching and signing for Nix binary cache
{ config, lib, pkgs, private, ... }:

{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # Cloudflare DNS token for ACME DNS-01 challenges
  age.secrets."cloudflare-dns-token" = {
    file = "${private}/nixos/secrets/cloudflare/cloudflare-dns-token.age";
  };

  # ACME (Let's Encrypt) with Cloudflare DNS-01 challenge
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "kamushadenes@hyades.io";
      dnsProvider = "cloudflare";
      environmentFile = config.age.secrets."cloudflare-dns-token".path;
    };
    certs."ncps.hyades.io" = { };
  };

  # Allow nginx to read ACME certs
  users.users.nginx.extraGroups = [ "acme" ];

  # Nginx reverse proxy: HTTPS → ncps container
  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedProxySettings = true;
    virtualHosts."ncps.hyades.io" = {
      forceSSL = true;
      useACMEHost = "ncps.hyades.io";
      locations."/" = {
        proxyPass = "http://127.0.0.1:8501";
      };
      # Nix binary cache uploads can be large
      extraConfig = ''
        client_max_body_size 0;
      '';
    };
  };

  # NFS mount for cache storage (TrueNAS at 10.23.23.14)
  fileSystems."/mnt/ncps" = {
    device = "10.23.23.14:/mnt/HDD/Cache/ncps";
    fsType = "nfs";
    options = [ "defaults" "_netdev" ];
  };

  # Enable Docker for ncps container
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # ncps container — listens on localhost only, nginx handles external traffic
  virtualisation.oci-containers = {
    backend = "docker";
    containers.ncps = {
      image = "kalbasit/ncps:latest";
      autoStart = true;
      ports = [ "127.0.0.1:8501:8501" ];
      volumes = [
        "/mnt/ncps:/storage"
      ];
      cmd = [
        "/bin/ncps"
        "serve"
        "--cache-hostname=ncps.hyades.io"
        "--cache-data-path=/storage"
        "--cache-database-url=sqlite:/storage/var/ncps/db/db.sqlite"
        "--cache-allow-put-verb=true"
        "--upstream-cache=https://cache.nixos.org"
        "--upstream-cache=https://nix-community.cachix.org"
        "--upstream-public-key=cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "--upstream-public-key=nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };

  # Ensure Docker waits for NFS mount
  systemd.services.docker-ncps = {
    after = [ "mnt-ncps.mount" ];
    requires = [ "mnt-ncps.mount" ];
  };

  # Open firewall for HTTPS (nginx) and keep 8501 for transition
  networking.firewall.allowedTCPPorts = [ 443 8501 ];

  # Disable NetworkManager (use systemd-networkd)
  networking.networkmanager.enable = lib.mkForce false;
}
