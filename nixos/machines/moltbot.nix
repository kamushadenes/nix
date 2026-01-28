# Machine configuration for moltbot LXC
# Moltbot-gateway - AI assistant gateway for Telegram
{ config, lib, pkgs, private, ... }:

{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # Agenix secrets for moltbot
  age.secrets = {
    "moltbot-telegram-token" = {
      file = "${private}/nixos/secrets/moltbot/telegram-bot-token.age";
      owner = "moltbot";
      group = "moltbot";
    };
    "moltbot-anthropic-key" = {
      file = "${private}/nixos/secrets/moltbot/anthropic-api-key.age";
      owner = "moltbot";
      group = "moltbot";
    };
    "moltbot-gateway-token" = {
      file = "${private}/nixos/secrets/moltbot/gateway-token.age";
      owner = "moltbot";
      group = "moltbot";
    };
  };

  # Create moltbot user (DynamicUser doesn't work with bind mounts)
  users.users.moltbot = {
    isSystemUser = true;
    group = "moltbot";
    home = "/var/lib/moltbot";
  };
  users.groups.moltbot = { };

  # Systemd service for moltbot-gateway
  systemd.services.moltbot-gateway = {
    description = "Moltbot Gateway - Telegram AI Assistant";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "5s";
      User = "moltbot";
      Group = "moltbot";
      StateDirectory = "moltbot";
      StateDirectoryMode = "0700";
      WorkingDirectory = "/var/lib/moltbot";
    };

    # Read secrets from agenix files and pass to moltbot-gateway
    script = ''
      export TELEGRAM_BOT_TOKEN=$(cat ${config.age.secrets."moltbot-telegram-token".path})
      export ANTHROPIC_API_KEY=$(cat ${config.age.secrets."moltbot-anthropic-key".path})
      export GATEWAY_TOKEN=$(cat ${config.age.secrets."moltbot-gateway-token".path})
      export MOLTBOT_DIR=/var/lib/moltbot
      export MOLTBOT_MODEL="anthropic/claude-sonnet-4-20250514"
      export MOLTBOT_THINKING_DEFAULT="medium"
      exec ${pkgs.moltbot-gateway}/bin/moltbot-gateway
    '';
  };

  # Ensure data directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/moltbot 0700 moltbot moltbot -"
  ];

  # Open firewall for gateway HTTP API (optional, for web UI)
  networking.firewall.allowedTCPPorts = [ 18789 ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;
}
