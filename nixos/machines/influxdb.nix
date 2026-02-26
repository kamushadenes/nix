# Machine configuration for influxdb LXC
# InfluxDB v2 time-series database for Proxmox native metrics
# Proxmox pushes metrics directly via its built-in metric server feature
{ config, lib, pkgs, private, ... }:
{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption (uses SSH host key)
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  age.secrets."influxdb-admin-password" = {
    file = "${private}/nixos/secrets/influxdb/admin-password.age";
    owner = "influxdb2";
    group = "influxdb2";
  };

  age.secrets."influxdb-admin-token" = {
    file = "${private}/nixos/secrets/influxdb/admin-token.age";
    owner = "influxdb2";
    group = "influxdb2";
  };

  services.influxdb2 = {
    enable = true;
    settings = {
      http-bind-address = "0.0.0.0:8086";
    };
    provision = {
      enable = true;
      initialSetup = {
        organization = "proxmox";
        bucket = "proxmox";
        username = "admin";
        retention = 2592000; # 30 days in seconds
        passwordFile = config.age.secrets."influxdb-admin-password".path;
        tokenFile = config.age.secrets."influxdb-admin-token".path;
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 8086 ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;
}
