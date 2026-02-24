# Machine configuration for prometheus LXC
# Central Prometheus server scraping all monitoring targets
# Also runs the Go-based PVE exporter (bigtcze/pve-exporter) for cluster-wide Proxmox metrics
{ config, lib, pkgs, packages, private, ... }:
let
  # Derive all scrape targets from nodes.json
  nodesData = builtins.fromJSON (builtins.readFile "${private}/nodes.json");
  nodes = nodesData.nodes;

  # Helper: get the first IP (targetHosts[0]) for a node
  nodeIp = name: builtins.head nodes.${name}.targetHosts;

  # PVE node names for iterating over per-node containers
  pveNodeNames = [ "pve1" "pve2" "pve3" ];

  # Exporter container IPs (prom-exporter-pve{1,2,3}) — still used for node_exporter scraping
  exporterIps = map (node: nodeIp "prom-exporter-${node}") pveNodeNames;

  # Cloudflared container IPs
  cloudflaredIps = map (node: nodeIp "cloudflared-${node}") pveNodeNames;
in
{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption (uses SSH host key)
  # lxc-management.nix adds the global LXC key via mkAfter
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # PVE API credentials for the Go exporter
  age.secrets."pve-config" = {
    file = "${private}/nixos/secrets/prometheus/pve-config.age";
  };

  # Go-based PVE exporter (bigtcze/pve-exporter)
  # Single instance scrapes entire cluster via PVE API
  systemd.services.pve-exporter = {
    description = "Proxmox VE Exporter (Go)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${packages.pve-exporter-go}/bin/pve-exporter -config ${config.age.secrets."pve-config".path}";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # Prometheus node_exporter for self-monitoring
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    listenAddress = "0.0.0.0";
  };

  # Prometheus server
  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = "0.0.0.0";
    retentionTime = "30d";

    scrapeConfigs = [
      # Node exporter - system metrics from all containers
      {
        job_name = "node";
        static_configs = [{
          targets = (map (ip: "${ip}:9100") exporterIps) ++ [ "localhost:9100" ];
        }];
      }

      # PVE exporter (Go) - cluster-wide Proxmox metrics from local instance
      {
        job_name = "pve";
        static_configs = [{
          targets = [ "localhost:9222" ];
        }];
      }

      # Cloudflared metrics from tunnel daemons
      {
        job_name = "cloudflared";
        static_configs = [{
          targets = map (ip: "${ip}:33399") cloudflaredIps;
        }];
      }
    ];
  };

  # Allow access to Prometheus UI/API, node_exporter, and PVE exporter
  networking.firewall.allowedTCPPorts = [ 9090 9100 9222 ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;
}
