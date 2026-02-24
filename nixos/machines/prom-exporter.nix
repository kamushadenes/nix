# Machine configuration for prom-exporter daemon LXCs
# Prometheus node_exporter on each Proxmox node
{ config, lib, pkgs, private, ... }:

{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption (uses SSH host key)
  # lxc-management.nix adds the global LXC key via mkAfter
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # Prometheus node_exporter - system metrics
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    listenAddress = "0.0.0.0";
  };

  # Allow Prometheus to scrape node_exporter
  networking.firewall.allowedTCPPorts = [ 9100 ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;
}
