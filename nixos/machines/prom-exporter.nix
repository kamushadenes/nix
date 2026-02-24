# Machine configuration for prom-exporter daemon LXCs
# Prometheus node_exporter + IPMI exporter on each Proxmox node
# Requires /dev/ipmi0 device passthrough from the host (pct set <vmid> -dev0 /dev/ipmi0)
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

  # IPMI exporter - hardware sensor metrics via /dev/ipmi0
  systemd.services.ipmi-exporter = {
    description = "Prometheus IPMI Exporter";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.freeipmi ];
    serviceConfig = {
      ExecStart = "${pkgs.prometheus-ipmi-exporter}/bin/ipmi_exporter --web.listen-address=:9290";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # Allow Prometheus to scrape both exporters
  networking.firewall.allowedTCPPorts = [ 9100 9290 ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;
}
