# Machine configuration for cloudflared LXC
# Cloudflare Tunnel with token-based authentication (dashboard-managed)
# All nodes share the same tunnel token - they're connectors to the same tunnel for HA
{ config, lib, pkgs, private, ... }:

{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption (uses SSH host key)
  # lxc-management.nix adds the global LXC key via mkAfter
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # Agenix secret for cloudflared tunnel token (shared across all nodes)
  age.secrets."cloudflared-token" = {
    file = "${private}/nixos/secrets/cloudflared/cloudflared-token.age";
    owner = "cloudflared";
    group = "cloudflared";
  };

  # Create static user for cloudflared (DynamicUser doesn't work with bind mounts)
  users.users.cloudflared = {
    isSystemUser = true;
    group = "cloudflared";
    home = "/var/lib/cloudflared";
  };
  users.groups.cloudflared = { };

  # Custom systemd service for token-based tunnel
  # Native services.cloudflared doesn't support token auth, only credential files
  systemd.services.cloudflared = {
    description = "Cloudflare Tunnel";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "5s";
      User = "cloudflared";
      Group = "cloudflared";
    };

    # Read token from agenix secret file and pass to cloudflared
    script = ''
      TOKEN=$(cat ${config.age.secrets."cloudflared-token".path})
      exec ${pkgs.cloudflared}/bin/cloudflared --no-autoupdate --metrics localhost:33399 tunnel run --token "$TOKEN"
    '';
  };

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;
}
