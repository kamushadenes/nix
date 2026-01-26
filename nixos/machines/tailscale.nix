# Machine configuration for tailscale daemon LXCs
# Tailscale subnet router for network access from anywhere
# Unlike cloudflared, each node needs its OWN state file (unique machine identity)
{ config, lib, pkgs, private, ... }:

{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption (uses SSH host key)
  # lxc-management.nix adds the global LXC key via mkAfter
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # Tailscale service
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both"; # Act as both subnet router and exit node
  };

  # Use native nftables mode for better firewall integration
  networking.nftables.enable = true;
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];

  # Enable IP forwarding for subnet routing
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # Firewall configuration for tailscale
  networking.firewall = {
    # Trust tailscale interface
    trustedInterfaces = [ "tailscale0" ];
    # Allow tailscale UDP port
    allowedUDPPorts = [ config.services.tailscale.port ];
    # Required for exit node functionality - prevents traffic from being dropped
    checkReversePath = "loose";
  };

  # UDP GRO optimization for better forwarding throughput
  # Fixes: "UDP GRO forwarding is suboptimally configured" warning
  services.networkd-dispatcher = {
    enable = true;
    rules."50-tailscale" = {
      onState = [ "routable" ];
      script = ''
        ${pkgs.ethtool}/bin/ethtool -K eth0 rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null || true
      '';
    };
  };

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;

  # Tailscale package for CLI access
  environment.systemPackages = [ pkgs.tailscale ];
}
