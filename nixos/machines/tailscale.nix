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
    # Use iptables for netfilter (matches origin config NetfilterMode: 2)
    useRoutingFeatures = "both"; # Act as both subnet router and exit node
  };

  # Enable IP forwarding for subnet routing
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # Firewall: allow tailscale traffic
  networking.firewall = {
    # Trust tailscale interface
    trustedInterfaces = [ "tailscale0" ];
    # Allow tailscale UDP port
    allowedUDPPorts = [ config.services.tailscale.port ];
  };

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;

  # Tailscale package for CLI access
  environment.systemPackages = [ pkgs.tailscale ];
}
