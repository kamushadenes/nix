# Machine configuration for prometheus LXC
# Central Prometheus server scraping all monitoring targets
{ config, lib, pkgs, private, ... }:

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
          targets = [
            "10.23.23.50:9100"  # prom-exporter-pve1
            "10.23.23.51:9100"  # prom-exporter-pve2
            "10.23.23.52:9100"  # prom-exporter-pve3
            "localhost:9100"    # prometheus self
          ];
        }];
      }

      # PVE exporter - Proxmox VE metrics
      # Each exporter runs on its Proxmox node's LXC, scraping the node's API
      {
        job_name = "pve";
        static_configs = [{
          targets = [
            "10.23.23.50:9221"  # prom-exporter-pve1
            "10.23.23.51:9221"  # prom-exporter-pve2
            "10.23.23.52:9221"  # prom-exporter-pve3
          ];
        }];
        # Map each exporter to its PVE node via ?target= parameter
        metrics_path = "/pve";
        params = { "cluster" = ["1"]; "node" = ["1"]; };
        relabel_configs = [
          # Map exporter IP to PVE node IP
          {
            source_labels = [ "__address__" ];
            regex = "10\\.23\\.23\\.50:9221";
            target_label = "__param_target";
            replacement = "10.23.5.10";
          }
          {
            source_labels = [ "__address__" ];
            regex = "10\\.23\\.23\\.51:9221";
            target_label = "__param_target";
            replacement = "10.23.5.11";
          }
          {
            source_labels = [ "__address__" ];
            regex = "10\\.23\\.23\\.52:9221";
            target_label = "__param_target";
            replacement = "10.23.5.12";
          }
          # Keep the exporter address as the actual scrape target
          {
            source_labels = [ "__param_target" ];
            target_label = "instance";
          }
        ];
      }

      # Cloudflared metrics from tunnel daemons
      {
        job_name = "cloudflared";
        static_configs = [{
          targets = [
            "10.23.23.82:33399"   # cloudflared-pve1
            "10.23.23.141:33399"  # cloudflared-pve2
            "10.23.23.217:33399"  # cloudflared-pve3
          ];
        }];
      }
    ];
  };

  # Allow access to Prometheus UI/API and node_exporter
  networking.firewall.allowedTCPPorts = [ 9090 9100 ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;
}
