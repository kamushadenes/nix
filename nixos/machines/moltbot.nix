# Machine configuration for moltbot LXC
# Moltbot-gateway - AI assistant gateway for Telegram
{ config, lib, pkgs, private, ... }:
let
  # Skill directories (skills are deployed via tmpfiles)
  caldavSkillDir = "${private}/nixos/machines/resources/moltbot/skills/caldav-calendar";
in
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
    "moltbot-google-key" = {
      file = "${private}/nixos/secrets/moltbot/google-api-key.age";
      owner = "moltbot";
      group = "moltbot";
    };
    "moltbot-brave-key" = {
      file = "${private}/nixos/secrets/moltbot/brave-api-key.age";
      owner = "moltbot";
      group = "moltbot";
    };
    "moltbot-fastmail-password" = {
      file = "${private}/nixos/secrets/moltbot/fastmail-password.age";
      owner = "moltbot";
      group = "moltbot";
    };
  };

  # Create moltbot user (DynamicUser doesn't work with bind mounts)
  users.users.moltbot = {
    isSystemUser = true;
    group = "moltbot";
    home = "/var/lib/moltbot";
    shell = pkgs.bash;
    # Allow login for interactive use
    createHome = true;
  };

  # Set up environment for moltbot user with full system PATH
  environment.variables = {
    # Ensure nix profile paths are available
    PATH = lib.mkForce "/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH";
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

    # Ensure moltbot binary and skill dependencies are in PATH
    path = [ pkgs.moltbot-gateway pkgs.bash pkgs.coreutils pkgs.vdirsyncer pkgs.khal ];

    # Read secrets from agenix files and pass to moltbot-gateway
    # Note: email config and auth-profiles.json are managed dynamically by moltbot
    script = ''
      export PATH="${pkgs.moltbot-gateway}/bin:$PATH"
      export TELEGRAM_BOT_TOKEN=$(cat ${config.age.secrets."moltbot-telegram-token".path})
      export ANTHROPIC_API_KEY=$(cat ${config.age.secrets."moltbot-anthropic-key".path})
      export GOOGLE_API_KEY=$(cat ${config.age.secrets."moltbot-google-key".path})
      export BRAVE_SEARCH_API_KEY=$(cat ${config.age.secrets."moltbot-brave-key".path})
      export GATEWAY_TOKEN=$(cat ${config.age.secrets."moltbot-gateway-token".path})
      export CLAWDBOT_GATEWAY_TOKEN=$GATEWAY_TOKEN
      export MOLTBOT_DIR=/var/lib/moltbot
      export MOLTBOT_THINKING_DEFAULT="medium"
      export FASTMAIL_USER="kamus@hadenes.io"
      export FASTMAIL_PASSWORD=$(cat ${config.age.secrets."moltbot-fastmail-password".path})

      exec ${pkgs.moltbot-gateway}/bin/moltbot gateway --port 18789
    '';
  };

  # Ensure data directories exist
  # Moltbot config at ~/.moltbot/moltbot.json is managed dynamically (not deployed via Nix)
  systemd.tmpfiles.rules = [
    "d /var/lib/moltbot 0700 moltbot moltbot -"
    "d /var/lib/moltbot/.moltbot 0700 moltbot moltbot -"
    "d /var/lib/moltbot/workspace 0700 moltbot moltbot -"
    "L /var/lib/moltbot/.clawdbot - - - - /var/lib/moltbot/.moltbot"
    # CalDAV calendar skill
    "d /var/lib/moltbot/.moltbot/skills/caldav-calendar 0700 moltbot moltbot -"
    "C /var/lib/moltbot/.moltbot/skills/caldav-calendar/SKILL.md 0600 moltbot moltbot - ${caldavSkillDir}/SKILL.md"
  ];

  # Open firewall for gateway HTTP API (optional, for web UI)
  networking.firewall.allowedTCPPorts = [ 18789 ];

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;

  # Add moltbot and skill dependencies to system PATH for all users
  environment.systemPackages = [ pkgs.moltbot-gateway pkgs.vdirsyncer pkgs.khal ];
}
