# Machine configuration for zigbee2mqtt LXC
# Zigbee2MQTT coordinator for Home Assistant integration
{ config, lib, pkgs, private, ... }:

{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption (uses SSH host key)
  # lxc-management.nix adds the global LXC key via mkAfter
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # Agenix secret for MQTT password
  age.secrets."zigbee2mqtt-mqtt-password" = {
    file = "${private}/nixos/secrets/zigbee2mqtt/mqtt-password.age";
    owner = "zigbee2mqtt";
    group = "zigbee2mqtt";
  };

  services.zigbee2mqtt = {
    enable = true;
    dataDir = "/var/lib/zigbee2mqtt";
    settings = {
      homeassistant = {
        enabled = true;
        experimental_event_entities = true;
      };
      mqtt = {
        base_topic = "zigbee2mqtt";
        server = "mqtt://mqtt.hyades.io";
        user = "haos";
        password = "!secret mqtt_password";
      };
      serial = {
        port = "/dev/serial/by-id/usb-ITEAD_SONOFF_Zigbee_3.0_USB_Dongle_Plus_V2_20240123191316-if00";
        adapter = "ember";
      };
      advanced = {
        channel = 25;
        last_seen = "epoch";
      };
      frontend = {
        enabled = true;
        port = 8080;
      };
    };
  };

  # Create secrets file for zigbee2mqtt before service starts
  # Note: preStart runs as zigbee2mqtt user, so no chown needed
  # Remove existing file first since it's chmod 400
  systemd.services.zigbee2mqtt.preStart = lib.mkAfter ''
    rm -f /var/lib/zigbee2mqtt/secret.yaml
    echo "mqtt_password: $(cat ${config.age.secrets."zigbee2mqtt-mqtt-password".path})" > /var/lib/zigbee2mqtt/secret.yaml
    chmod 400 /var/lib/zigbee2mqtt/secret.yaml
  '';

  # Open firewall for frontend
  networking.firewall.allowedTCPPorts = [ 8080 ];

  # Create static user for zigbee2mqtt (DynamicUser doesn't work with bind mounts)
  users.users.zigbee2mqtt = {
    isSystemUser = true;
    group = "zigbee2mqtt";
    home = "/var/lib/zigbee2mqtt";
    extraGroups = [ "dialout" "lp" ]; # For serial device access (lp needed in container)
  };
  users.groups.zigbee2mqtt = { };

  # Override systemd unit to use static user instead of DynamicUser
  # Also relax device policy for USB access in LXC
  systemd.services.zigbee2mqtt = {
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "zigbee2mqtt";
      Group = "zigbee2mqtt";
      StateDirectory = "zigbee2mqtt";
      StateDirectoryMode = "0700";
      # Relax device sandbox for USB passthrough in LXC
      DevicePolicy = lib.mkForce "auto";
      DeviceAllow = lib.mkForce [ "/dev/ttyACM0" "/dev/serial/by-id/usb-ITEAD_SONOFF_Zigbee_3.0_USB_Dongle_Plus_V2_20240123191316-if00" ];
    };
  };

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;
}
