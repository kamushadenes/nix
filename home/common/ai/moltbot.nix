# Moltbot - AI assistant gateway for Telegram
#
# Uses nix-moltbot for declarative configuration.
# Runs as a launchd service on macOS, systemd user service on Linux.
#
# Setup:
# 1. Create Telegram bot via @BotFather, get the token
# 2. Get your Telegram user ID via @userinfobot
# 3. Create and encrypt secrets with agenix:
#    cd ~/.config/nix/config/private
#    echo "YOUR_BOT_TOKEN" | agenix -e home/common/ai/resources/moltbot/telegram-bot-token.age
#    echo "YOUR_ANTHROPIC_KEY" | agenix -e home/common/ai/resources/moltbot/anthropic-api-key.age
# 4. Update allowFrom in this file with your Telegram user ID(s)
# 5. Rebuild: rebuild
#
# Resources:
# - README: https://github.com/moltbot/nix-moltbot
# - Plugins: https://github.com/moltbot/nix-steipete-tools
{
  config,
  lib,
  pkgs,
  private,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  secretsDir = "${homeDir}/.moltbot/secrets";

  # Disabled - moltbot now runs as a system service on moltbot LXC
  enabled = false;

  # Check if secrets exist
  telegramTokenAgeFile = "${private}/home/common/ai/resources/moltbot/telegram-bot-token.age";
  anthropicKeyAgeFile = "${private}/home/common/ai/resources/moltbot/anthropic-api-key.age";
  gatewayTokenAgeFile = "${private}/home/common/ai/resources/moltbot/gateway-token.age";
  secretsExist = enabled && builtins.pathExists anthropicKeyAgeFile;

  # Agenix secrets paths (decrypted at runtime)
  telegramTokenPath = "${secretsDir}/telegram-bot-token";
  anthropicKeyPath = "${secretsDir}/anthropic-api-key";
  gatewayTokenPath = "${secretsDir}/gateway-token";

  # Use full moltbot package with lower priority to avoid conflicts
  moltbotPackage = lib.lowPrio pkgs.moltbot;
in
{
  # Agenix secrets for moltbot (only if the .age files exist)
  age.secrets = lib.mkIf secretsExist {
    moltbot-telegram-token = {
      file = telegramTokenAgeFile;
      path = telegramTokenPath;
    };
    moltbot-anthropic-key = {
      file = anthropicKeyAgeFile;
      path = anthropicKeyPath;
    };
    moltbot-gateway-token = {
      file = gatewayTokenAgeFile;
      path = gatewayTokenPath;
    };
  };

  # Moltbot config using instances API (required for proper defaults)
  programs.moltbot = lib.mkIf secretsExist {
    # AI model defaults
    defaults = {
      model = "anthropic/claude-sonnet-4-20250514";
      thinkingDefault = "medium";
    };

    # Use full moltbot package with conflicts removed
    package = moltbotPackage;

    # Use instances.default for proper configuration
    instances.default = {
      enable = true;

      # Use full moltbot package with conflicts removed
      package = moltbotPackage;

      # Telegram provider
      providers.telegram = {
        enable = true;
        botTokenFile = telegramTokenPath;
        allowFrom = [ 28814201 ]; # @kamushadenes
      };

      # Anthropic API key
      providers.anthropic.apiKeyFile = anthropicKeyPath;

      # Gateway auth token
      gateway.tokenFile = gatewayTokenPath;

      # No plugins (upstream nix-steipete-tools doesn't export moltbotPlugin yet)
      plugins = [];

      # Disable memory plugin (not needed for basic Telegram)
      configOverrides = {
        plugins.slots.memory = "none";
      };
    };
  };

  # Create .env file for moltbot with API key from agenix-decrypted secret
  home.activation.moltbot-env = lib.mkIf secretsExist (
    lib.hm.dag.entryAfter [ "agenix" ] ''
      if [ -f "${anthropicKeyPath}" ]; then
        $DRY_RUN_CMD mkdir -p "${homeDir}/.moltbot"
        $DRY_RUN_CMD sh -c 'echo "ANTHROPIC_API_KEY=$(cat "${anthropicKeyPath}")" > "${homeDir}/.moltbot/.env"'
        $DRY_RUN_CMD chmod 600 "${homeDir}/.moltbot/.env"
      fi
    ''
  );

  # Warning if secrets don't exist
  warnings = lib.optional (!secretsExist) ''
    Moltbot is disabled because secrets are not configured.
    To enable, create the encrypted secrets:
      cd ~/.config/nix/config/private
      echo "YOUR_TELEGRAM_BOT_TOKEN" | agenix -e home/common/ai/resources/moltbot/telegram-bot-token.age
      echo "YOUR_ANTHROPIC_API_KEY" | agenix -e home/common/ai/resources/moltbot/anthropic-api-key.age
    Then update allowFrom in home/common/ai/moltbot.nix with your Telegram user ID.
  '';
}
