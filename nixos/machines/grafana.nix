# Machine configuration for grafana LXC
# Grafana visualization server connected to Prometheus
{ config, lib, pkgs, private, ... }:
let
  # Derive Prometheus URL from nodes.json
  nodesData = builtins.fromJSON (builtins.readFile "${private}/nodes.json");
  nodes = nodesData.nodes;
  nodeIp = name: builtins.head nodes.${name}.targetHosts;
  prometheusUrl = "http://${nodeIp "prometheus"}:9090";
  influxdbUrl = "http://${nodeIp "influxdb"}:8086";

  # Dashboard JSON files to provision
  dashboardDir = ./resources/grafana/dashboards;
in
{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption (uses SSH host key)
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  age.secrets."grafana-admin-password" = {
    file = "${private}/nixos/secrets/grafana/admin-password.age";
    owner = "grafana";
    group = "grafana";
  };

  age.secrets."grafana-influxdb-token" = {
    file = "${private}/nixos/secrets/grafana/influxdb-token.age";
    owner = "grafana";
    group = "grafana";
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
      };
      security = {
        admin_user = "admin";
        admin_password = "$__file{${config.age.secrets."grafana-admin-password".path}}";
      };
      analytics.reporting_enabled = false;
    };

    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            uid = "prometheus";
            url = prometheusUrl;
            access = "proxy";
            isDefault = true;
            editable = false;
          }
          {
            name = "InfluxDB";
            type = "influxdb";
            uid = "influxdb";
            url = influxdbUrl;
            access = "proxy";
            editable = false;
            jsonData = {
              version = "Flux";
              organization = "proxmox";
              defaultBucket = "proxmox";
            };
            secureJsonData = {
              token = "$__file{${config.age.secrets."grafana-influxdb-token".path}}";
            };
          }
        ];
      };
      dashboards.settings = {
        apiVersion = 1;
        providers = [{
          name = "default";
          type = "file";
          options.path = "/var/lib/grafana/dashboards";
          disableDeletion = false;
        }];
      };
    };
  };

  # Deploy dashboard JSON files
  systemd.tmpfiles.rules =
    let
      dashboardFiles = builtins.attrNames (builtins.readDir dashboardDir);
    in
    [ "d /var/lib/grafana/dashboards 0755 grafana grafana -" ]
    ++ map (f: "L+ /var/lib/grafana/dashboards/${f} - - - - ${dashboardDir}/${f}") dashboardFiles;

  networking.firewall.allowedTCPPorts = [ 3000 ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;
}
