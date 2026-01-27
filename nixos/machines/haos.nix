# Machine configuration for haos LXC
# Home Assistant native NixOS service (not Docker)
{ config, lib, pkgs, pkgs-unstable, private, ... }:

let
  # Load custom components and lovelace modules
  customComponents = import ./haos-custom-components.nix { pkgs = pkgs-unstable; };
  customLovelaceModules = import ./haos-lovelace-modules.nix { pkgs = pkgs-unstable; };

  # YAML config files from private submodule
  haosConfigDir = "${private}/nixos/haos-config";
in
{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption (uses SSH host key)
  # lxc-management.nix adds the global LXC key via mkAfter
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # Agenix secrets for Home Assistant
  age.secrets = {
    "haos-secrets.yaml" = {
      file = "${private}/nixos/secrets/haos/secrets.yaml.age";
      path = "/var/lib/hass/secrets.yaml";
      owner = "hass";
      group = "hass";
      mode = "0400";
    };
  };

  # Home Assistant service configuration
  services.home-assistant = {
    enable = true;
    openFirewall = true;

    # Use UNSTABLE Home Assistant for latest features
    package = (pkgs-unstable.home-assistant.override {
      extraPackages = ps: with ps; [
        # Python packages needed by integrations
        aiohomekit      # HomeKit controller
        aioesphomeapi   # ESPHome integration
        psycopg2        # PostgreSQL (if using external recorder)
        securetar       # Backup support
        # Packages for migrated integrations
        getmac          # Samsung TV
        caldav          # CalDAV calendar
        pycryptodome    # BLE Adv (Crypto module)
        fido2           # iCloud3
        srp             # iCloud3 secure remote password
        httpx-auth      # ICS Calendar authentication
        arrow           # Date/time library for various integrations
        ics             # ICS Calendar parsing
      ];
      extraComponents = [
        # Core components that might need extra deps
        "esphome"
        "homekit_controller"
        "mobile_app"
        "cast"
        "bluetooth"
        "zeroconf"
        "ssdp"
        "usb"
        "dhcp"
        "radio_browser"
        "unifi"
        "unifiprotect"
        "mqtt"
        "zha"  # Zigbee (though using Z2M externally)
        "spotify"
        "google_translate"
        "openweathermap"
        "co2signal"
        "github"
        "google_assistant"
        "rest"
        "command_line"
        "template"
        "group"
        "input_boolean"
        "input_datetime"
        "input_number"
        "input_select"
        "input_text"
        "counter"
        "timer"
        "schedule"
        "scene"
        "script"
        "automation"
        "person"
        "zone"
        "sun"
        "moon"
        "season"
        "time_date"
        "workday"
        "calendar"
        "todo"
        "shopping_list"
        "utility_meter"
        "history_stats"
        "statistics"
        "min_max"
        "derivative"
        "integration"
        "trend"
        "threshold"
        "bayesian"
        "generic_thermostat"
        "proximity"
        "notify"
        "persistent_notification"
        "file"
        "image"
        "webhook"
        "tag"
        "conversation"
        "intent_script"
        "homeassistant_alerts"
        # Migrated integrations
        "ipp"
        "wled"
        "nextdns"
        "todoist"
        "samsungtv"
        "caldav"
        "apple_tv"
        "homekit"
        "wyoming"
        "google_sheets"
        "smartthings"
      ];
    });

    # Allow UI to modify config files (automations, scenes, scripts)
    configWritable = true;
    lovelaceConfigWritable = true;

    # Custom components built declaratively
    customComponents = customComponents;
    customLovelaceModules = customLovelaceModules;

    # Base config - most config comes from migrated files
    config = {
      homeassistant = {
        name = "Home";
        latitude = "!secret latitude";
        longitude = "!secret longitude";
        elevation = "!secret elevation";
        unit_system = "metric";
        time_zone = "America/Sao_Paulo";
        currency = "BRL";
        country = "BR";
        internal_url = "http://haos.hyades.io:8123";
        external_url = "!secret external_url";
        customize = "!include customize.yaml";
      };

      # Default integrations
      default_config = {};

      # Include YAML config files (deployed from private submodule)
      alert = "!include alert.yaml";
      template = "!include template.yaml";

      # Frontend themes
      frontend = {
        themes = "!include_dir_merge_named themes";
      };

      # MQTT sensors from YAML
      mqtt = {
        sensor = "!include mqtt_sensor.yaml";
      };

      # HTTP configuration
      http = {
        server_port = 8123;
        use_x_forwarded_for = true;
        trusted_proxies = [
          "172.16.0.0/12"  # Docker networks
          "10.0.0.0/8"     # Internal networks
          "127.0.0.1"      # Localhost
        ];
      };

      # Recorder for history (use default SQLite for now)
      recorder = {
        db_url = "sqlite:////var/lib/hass/home-assistant_v2.db";
        purge_keep_days = 30;
      };

      # Logger configuration
      logger = {
        default = "info";
        logs = {
          "homeassistant.components.mqtt" = "warning";
          "homeassistant.components.unifi" = "warning";
        };
      };

      # MQTT is configured via UI (stored in .storage/core.config_entries)
      # Do NOT add mqtt broker config here - it causes conflicts

      # Lovelace configuration with YAML dashboards
      lovelace = {
        mode = "storage";
        dashboards = {
          "main-dashboard" = {
            mode = "yaml";
            title = "Dashboard";
            icon = "mdi:home";
            show_in_sidebar = true;
            filename = "dashboard.yaml";
          };
          "floor-plan" = {
            mode = "yaml";
            title = "Floor Plan";
            icon = "mdi:floor-plan";
            show_in_sidebar = true;
            filename = "floorplan.yaml";
          };
        };
      };
    };
  };

  # Firewall
  networking.firewall.allowedTCPPorts = [
    8123  # Home Assistant web UI
    # 8300  # Matter (if needed later)
  ];

  # Static user for Home Assistant (DynamicUser doesn't work with bind mounts)
  users.users.hass = {
    isSystemUser = true;
    group = "hass";
    home = "/var/lib/hass";
    # Groups for device access if needed in future
    extraGroups = [ "dialout" ];
  };
  users.groups.hass = { };

  # Ensure config directory exists with correct permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/hass 0750 hass hass -"
  ];

  # Override systemd unit to use static user instead of DynamicUser
  systemd.services.home-assistant = {
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "hass";
      Group = "hass";
      StateDirectory = lib.mkForce "";  # We manage this ourselves
      # Increase memory limit for large HA installations
      MemoryMax = "6G";
      # Increase file descriptor limit for HACS and large installations
      LimitNOFILE = 65536;
      # Disable private /tmp so HACS can write to /tmp/hacs_backup
      PrivateTmp = lib.mkForce false;
    };
    # Ensure secrets are available before starting
    after = [ "agenix.service" ];
    wants = [ "agenix.service" ];
  };

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;

  # Deploy YAML config files from private submodule
  # These are copied (not symlinked) so they can be edited via UI if needed
  system.activationScripts.haosConfig = {
    deps = [ "users" "groups" ];
    text = ''
      # Copy YAML config files to Home Assistant directory
      install -m 0644 -o hass -g hass ${haosConfigDir}/dashboard.yaml /var/lib/hass/dashboard.yaml
      install -m 0644 -o hass -g hass ${haosConfigDir}/floorplan.yaml /var/lib/hass/floorplan.yaml
      install -m 0644 -o hass -g hass ${haosConfigDir}/floorplan_data.yaml /var/lib/hass/floorplan_data.yaml
      install -m 0644 -o hass -g hass ${haosConfigDir}/alert.yaml /var/lib/hass/alert.yaml
      install -m 0644 -o hass -g hass ${haosConfigDir}/customize.yaml /var/lib/hass/customize.yaml
      install -m 0644 -o hass -g hass ${haosConfigDir}/mqtt_sensor.yaml /var/lib/hass/mqtt_sensor.yaml
      install -m 0644 -o hass -g hass ${haosConfigDir}/template.yaml /var/lib/hass/template.yaml
    '';
  };

  # Increase system-wide file descriptor limits
  security.pam.loginLimits = [
    { domain = "*"; type = "soft"; item = "nofile"; value = "65536"; }
    { domain = "*"; type = "hard"; item = "nofile"; value = "65536"; }
  ];
}
