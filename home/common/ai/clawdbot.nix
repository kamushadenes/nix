# Clawdbot - AI assistant gateway for Telegram
#
# STATUS: DISABLED - nix-clawdbot module has compatibility issues with clawdbot 2026.x:
#   - Generates deprecated 'byProvider' key (now 'byChannel')
#   - Generates 'telegram' at root instead of 'channels.telegram'
#   - clawdbot expects 'memory-core' plugin not included in gateway package
# TODO: File upstream issues or wait for nix-clawdbot updates
#
# Uses nix-clawdbot (github:moltbot/nix-moltbot) for declarative configuration.
# Runs as a launchd service on macOS, systemd user service on Linux.
#
# Setup:
# 1. Create Telegram bot via @BotFather, get the token
# 2. Get your Telegram user ID via @userinfobot
# 3. Create and encrypt secrets with agenix:
#    cd ~/.config/nix/config/private
#    echo "YOUR_BOT_TOKEN" | agenix -e home/common/ai/resources/clawdbot/telegram-bot-token.age
#    echo "YOUR_ANTHROPIC_KEY" | agenix -e home/common/ai/resources/clawdbot/anthropic-api-key.age
# 4. Update allowFrom in this file with your Telegram user ID(s)
# 5. Rebuild: rebuild
#
# Resources:
# - README: https://github.com/moltbot/nix-moltbot
# - Plugins: https://github.com/clawdbot/nix-steipete-tools
{
  config,
  lib,
  pkgs,
  private,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  secretsDir = "${homeDir}/.clawdbot/secrets";

  # Disabled until upstream nix-clawdbot module is updated for clawdbot 2026.x
  # See header comment for details on compatibility issues
  enabled = false;

  # Check if secrets exist
  telegramTokenAgeFile = "${private}/home/common/ai/resources/clawdbot/telegram-bot-token.age";
  anthropicKeyAgeFile = "${private}/home/common/ai/resources/clawdbot/anthropic-api-key.age";
  secretsExist = enabled && builtins.pathExists telegramTokenAgeFile && builtins.pathExists anthropicKeyAgeFile;

  # Agenix secrets paths (decrypted at runtime)
  telegramTokenPath = "${secretsDir}/telegram-bot-token";
  anthropicKeyPath = "${secretsDir}/anthropic-api-key";
in
{
  # Agenix secrets for clawdbot (only if the .age files exist)
  age.secrets = lib.mkIf secretsExist {
    clawdbot-telegram-token = {
      file = telegramTokenAgeFile;
      path = telegramTokenPath;
    };
    clawdbot-anthropic-key = {
      file = anthropicKeyAgeFile;
      path = anthropicKeyPath;
    };
  };

  # Use instances API to work around upstream bug with default instance systemd options
  programs.clawdbot = lib.mkIf secretsExist {
    # Use gateway-only package to avoid conflicts with system tools
    # The batteries-included package bundles python, gotools, etc. that conflict
    package = pkgs.clawdbot-gateway;

    # Don't expose plugin packages to avoid more conflicts
    exposePluginPackages = false;

    # AI model defaults
    defaults = {
      model = "anthropic/claude-sonnet-4-20250514"; # Fast and capable
      thinkingDefault = "medium";
    };

    # First-party plugins
    # Note: bird (Twitter/X) disabled due to SSL download issues
    firstParty = {
      summarize.enable = true; # Summarize web pages, PDFs, videos
      peekaboo.enable = true; # Take screenshots
      oracle.enable = true; # Web search
      poltergeist.enable = true; # Control macOS UI
      sag.enable = true; # Text-to-speech
      camsnap.enable = true; # Camera snapshots
      gogcli.enable = true; # Google Calendar
      bird.enable = false; # Twitter/X - disabled (SSL download issues)
      sonoscli.enable = true; # Sonos control
      imsg.enable = true; # iMessage
    };

    # Use named instance to get proper defaults for all nested options
    instances.default = {
      enable = true;

      # Explicitly set gateway-only package at instance level too
      package = pkgs.clawdbot-gateway;

      # Anthropic API key
      providers.anthropic.apiKeyFile = anthropicKeyPath;

      # Disable built-in telegram provider (generates outdated config structure)
      # We configure it manually via configOverrides below
      providers.telegram.enable = false;

      # Work around upstream bugs in config generation
      configOverrides = {
        # Telegram channel (upstream generates "telegram" instead of "channels.telegram")
        channels = {
          telegram = {
            enabled = true;
            tokenFile = telegramTokenPath;
            allowFrom = [ 28814201 ]; # @kamushadenes
          };
        };
        # Queue settings (upstream generates "byProvider" instead of "byChannel")
        messages.queue.byChannel = {
          telegram = "interrupt";
          discord = "queue";
          webchat = "queue";
        };
        # Note: plugins section is omitted - clawdbot generates defaults
      };
    };
  };

  # Create .env file for clawdbot with API key from agenix-decrypted secret
  # This runs after agenix decrypts the secrets
  home.activation.clawdbot-env = lib.mkIf secretsExist (
    lib.hm.dag.entryAfter [ "agenix" ] ''
      if [ -f "${anthropicKeyPath}" ]; then
        $DRY_RUN_CMD mkdir -p "${homeDir}/.clawdbot"
        $DRY_RUN_CMD sh -c 'echo "ANTHROPIC_API_KEY=$(cat "${anthropicKeyPath}")" > "${homeDir}/.clawdbot/.env"'
        $DRY_RUN_CMD chmod 600 "${homeDir}/.clawdbot/.env"
      fi
    ''
  );

  # Fix clawdbot config by removing deprecated keys that upstream module generates
  # The nix-clawdbot module generates "byProvider" but clawdbot now expects only "byChannel"
  home.activation.clawdbot-config-fix = lib.mkIf secretsExist (
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      config_file="${homeDir}/.clawdbot/clawdbot.json"
      if [ -L "$config_file" ]; then
        # Config is a symlink from home-manager, copy and fix it
        real_config=$(readlink -f "$config_file")
        rm "$config_file"
        ${pkgs.jq}/bin/jq 'del(.messages.queue.byProvider)' "$real_config" > "$config_file"
        chmod 600 "$config_file"
      fi
    ''
  );

  # Warning if secrets don't exist
  warnings = lib.optional (!secretsExist) ''
    Clawdbot is disabled because secrets are not configured.
    To enable, create the encrypted secrets:
      cd ~/.config/nix/config/private
      echo "YOUR_TELEGRAM_BOT_TOKEN" | agenix -e home/common/ai/resources/clawdbot/telegram-bot-token.age
      echo "YOUR_ANTHROPIC_API_KEY" | agenix -e home/common/ai/resources/clawdbot/anthropic-api-key.age
    Then update allowFrom in home/common/ai/clawdbot.nix with your Telegram user ID.
  '';
}
