# Machine configuration for mqtt LXC
# Mosquitto MQTT broker for Home Assistant integration
{ config, lib, pkgs, private, ... }:

{
  # Agenix secret for mosquitto password
  age.secrets."mosquitto-passwd" = {
    file = "${private}/nixos/secrets/mqtt/mosquitto-passwd.age";
    owner = "mosquitto";
    group = "mosquitto";
  };

  services.mosquitto = {
    enable = true;
    persistence = true;
    dataDir = "/var/lib/mosquitto";
    listeners = [{
      port = 1883;
      address = "0.0.0.0";
      settings.allow_anonymous = false;
      users.haos = {
        hashedPasswordFile = config.age.secrets."mosquitto-passwd".path;
      };
    }];
  };

  # Open firewall for MQTT
  networking.firewall.allowedTCPPorts = [ 1883 ];

  # Create static user for mosquitto (DynamicUser doesn't work with bind mounts)
  users.users.mosquitto = {
    isSystemUser = true;
    group = "mosquitto";
    home = "/var/lib/mosquitto";
  };
  users.groups.mosquitto = { };

  # Override systemd unit to use static user instead of DynamicUser
  # DynamicUser + PrivateMounts + bind mounts = permission issues
  systemd.services.mosquitto = {
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "mosquitto";
      Group = "mosquitto";
      StateDirectory = "mosquitto";
      StateDirectoryMode = "0700";
    };
  };

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;
}
