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
    extraDaemonFlags = [ "--no-logs-no-support" ]; # Disable telemetry
    extraSetFlags = [
      "--advertise-routes=10.23.23.0/24,10.23.5.0/24,10.23.2.0/24"
      "--advertise-exit-node"
      "--accept-routes"
    ];
  };

  # Use native nftables mode for better firewall integration
  networking.nftables.enable = true;
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];

  # Ensure tailscaled-set waits for tailscaled to be fully ready
  systemd.services.tailscaled-set = {
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
    serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
  };

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

  # Ensure local subnet traffic uses eth0 instead of tailscale0
  # When accept-routes is enabled, tailscale adds routes for advertised subnets
  # through tailscale0 in table 52, which conflicts with the local eth0 interface.
  # This high-priority rule forces local traffic to use the main routing table.
  systemd.services.tailscale-route-fix = {
    description = "Fix routing for local subnets with tailscale accept-routes";
    after = [ "tailscaled.service" "tailscaled-set.service" ];
    wants = [ "tailscaled-set.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "tailscale-route-fix" ''
        # Add high-priority rules for locally-connected subnets
        # Priority 5200 is before tailscale's rules (5210+)
        ${pkgs.iproute2}/bin/ip rule add to 10.23.23.0/24 lookup main priority 5200 2>/dev/null || true
        ${pkgs.iproute2}/bin/ip rule add to 10.23.5.0/24 lookup main priority 5200 2>/dev/null || true
        ${pkgs.iproute2}/bin/ip rule add to 10.23.2.0/24 lookup main priority 5200 2>/dev/null || true
      '';
    };
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
