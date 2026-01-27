# Machine configuration for waha LXC
# WAHA - WhatsApp HTTP API (https://waha.devlike.pro)
{ config, lib, pkgs, private, ... }:

{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # WAHA environment variables (API keys, passwords, S3 credentials)
  age.secrets."waha-env" = {
    file = "${private}/nixos/secrets/waha/waha-env.age";
    path = "/run/agenix/waha-env";
    mode = "0400";
  };

  # Docker Hub PAT for pulling devlikeapro/waha-plus (private image)
  age.secrets."docker-token" = {
    file = "${private}/nixos/secrets/waha/docker-token.age";
    path = "/run/agenix/docker-token";
    mode = "0400";
  };

  # Enable Docker for WAHA container
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # Pre-pull script: login, pull image, logout
  # Runs before the container service starts
  systemd.services.waha-image-pull = {
    description = "Pull WAHA Plus Docker image with authentication";
    after = [ "docker.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    before = [ "docker-waha.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      TOKEN=$(cat /run/agenix/waha-env | ${pkgs.gnugrep}/bin/grep -oP 'DOCKER_TOKEN=\K.*' || cat /run/agenix/docker-token)
      echo "$TOKEN" | ${pkgs.docker}/bin/docker login -u devlikeapro --password-stdin
      ${pkgs.docker}/bin/docker pull devlikeapro/waha-plus:gows
      ${pkgs.docker}/bin/docker logout
    '';
  };

  # Make container service depend on image pull
  systemd.services.docker-waha = {
    after = [ "waha-image-pull.service" ];
    requires = [ "waha-image-pull.service" ];
  };

  # WAHA container
  virtualisation.oci-containers = {
    backend = "docker";
    containers.waha = {
      image = "devlikeapro/waha-plus:gows";
      autoStart = true;
      ports = [ "3000:3000" ];
      volumes = [
        "/var/lib/waha/sessions:/app/.sessions"
        "/var/lib/waha/media:/app/.media"
        "/etc/localtime:/etc/localtime:ro"
      ];
      environmentFiles = [ "/run/agenix/waha-env" ];
      environment = {
        TZ = "America/Sao_Paulo";
        WAHA_BASE_URL = "https://waha.hyades.io";
        WHATSAPP_API_SCHEMA = "http";
        WHATSAPP_API_PORT = "3000";
        WHATSAPP_API_HOSTNAME = "localhost";
        WAHA_LOG_FORMAT = "JSON";
        WAHA_LOG_LEVEL = "info";
        WAHA_DASHBOARD_ENABLED = "true";
        WHATSAPP_DEFAULT_ENGINE = "GOWS";
        WHATSAPP_FILES_FOLDER = "/app/.media";
        WHATSAPP_FILES_LIFETIME = "0";
        WAHA_MEDIA_STORAGE = "LOCAL";
        WAHA_PRINT_QR = "True";
        WHATSAPP_RESTART_ALL_SESSIONS = "True";
        WHATSAPP_SWAGGER_ENABLED = "true";
        WHATSAPP_API_KEY_EXCLUDE_PATH = "health,ping";
        # S3 config (non-secret parts)
        WAHA_S3_REGION = "us-east1";
        WAHA_S3_BUCKET = "ranchodojuca";
        WAHA_S3_ENDPOINT = "https://f6934f56ce237241104dbe9302cee786.r2.cloudflarestorage.com";
        WAHA_S3_FORCE_PATH_STYLE = "True";
        WAHA_S3_PROXY_FILES = "True";
      };
    };
  };

  # Ensure data directories exist
  systemd.tmpfiles.rules = [
    "d /var/lib/waha 0755 root root -"
    "d /var/lib/waha/sessions 0755 root root -"
    "d /var/lib/waha/media 0755 root root -"
  ];

  # Open firewall for WAHA API
  networking.firewall.allowedTCPPorts = [ 3000 ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;
}
