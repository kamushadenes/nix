# Machine configuration for esphome LXC
# ESPHome builder and interface for Home Assistant
{ config, lib, pkgs, private, ... }:

{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption (uses SSH host key)
  # lxc-management.nix adds the global LXC key via mkAfter
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # Agenix secret for ESPHome WiFi credentials
  age.secrets."esphome-secrets.yaml" = {
    file = "${private}/nixos/secrets/esphome/esphome-secrets.yaml.age";
    path = "/var/lib/esphome/secrets.yaml";
    mode = "0644";
  };

  # Enable Docker for ESPHome container
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # ESPHome container
  virtualisation.oci-containers = {
    backend = "docker";
    containers.esphome = {
      image = "ghcr.io/esphome/esphome:latest";
      autoStart = true;
      ports = [ "6052:6052" ];
      volumes = [
        "/var/lib/esphome:/config"
        "/etc/localtime:/etc/localtime:ro"
        # USB device access for flashing
        "/dev:/dev"
      ];
      environment = {
        ESPHOME_DASHBOARD_USE_PING = "true";
      };
      extraOptions = [
        "--privileged"  # Required for USB device access
        "--network=host"  # Better for mDNS discovery
      ];
    };
  };

  # Open firewall for ESPHome dashboard
  networking.firewall.allowedTCPPorts = [ 6052 ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;

  # Ensure config directory exists with correct permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/esphome 0755 root root -"
  ];
}
