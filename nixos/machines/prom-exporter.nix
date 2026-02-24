# Machine configuration for prom-exporter daemon LXCs
# Prometheus node_exporter + pve_exporter on each Proxmox node
# All nodes share the same PVE API credentials but have their own host keys
{ config, lib, pkgs, private, ... }:

{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption (uses SSH host key)
  # lxc-management.nix adds the global LXC key via mkAfter
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # Agenix secret for PVE API credentials (shared across all nodes)
  age.secrets."pve-env" = {
    file = "${private}/nixos/secrets/prom-exporter/pve-env.age";
  };

  # Prometheus node_exporter - system metrics
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    listenAddress = "0.0.0.0";
  };

  # Prometheus pve_exporter - Proxmox VE metrics
  services.prometheus.exporters.pve = {
    enable = true;
    port = 9221;
    listenAddress = "0.0.0.0";
    environmentFile = config.age.secrets."pve-env".path;
  };

  # Allow Prometheus to scrape both exporters
  networking.firewall.allowedTCPPorts = [ 9100 9221 ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;
}
