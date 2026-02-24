# Machine configuration for prometheus LXC
# Central Prometheus server scraping all monitoring targets
{ config, lib, pkgs, private, ... }:
let
  # Derive all scrape targets from nodes.json
  nodesData = builtins.fromJSON (builtins.readFile "${private}/nodes.json");
  nodes = nodesData.nodes;

  # Helper: get the first IP (targetHosts[0]) for a node
  nodeIp = name: builtins.head nodes.${name}.targetHosts;

  # PVE node name -> host IP mapping
  pveNodes = {
    pve1 = "10.23.5.10";
    pve2 = "10.23.5.11";
    pve3 = "10.23.5.12";
  };
  pveNodeNames = builtins.attrNames pveNodes;

  # Exporter container IPs (prom-exporter-pve{1,2,3})
  exporterIps = map (node: nodeIp "prom-exporter-${node}") pveNodeNames;

  # Cloudflared container IPs
  cloudflaredIps = map (node: nodeIp "cloudflared-${node}") pveNodeNames;

  # Build PVE relabel configs: map each exporter IP to its PVE node IP
  pveRelabelConfigs = (lib.imap0 (i: node: {
    source_labels = [ "__address__" ];
    regex = lib.replaceStrings ["."] ["\\."] (builtins.elemAt exporterIps i) + ":9221";
    target_label = "__param_target";
    replacement = pveNodes.${node};
  }) pveNodeNames) ++ [
    # Keep the PVE node IP as the instance label
    {
      source_labels = [ "__param_target" ];
      target_label = "instance";
    }
  ];
in
{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption (uses SSH host key)
  # lxc-management.nix adds the global LXC key via mkAfter
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

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

      # PVE exporter - Proxmox VE metrics
      # Each exporter runs on its Proxmox node's LXC, scraping the node's API
      {
        job_name = "pve";
        static_configs = [{
          targets = map (ip: "${ip}:9221") exporterIps;
        }];
        metrics_path = "/pve";
        params = { "cluster" = ["1"]; "node" = ["1"]; };
        relabel_configs = pveRelabelConfigs;
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

  # Allow access to Prometheus UI/API and node_exporter
  networking.firewall.allowedTCPPorts = [ 9090 9100 ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;
}
