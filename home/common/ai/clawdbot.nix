# Clawdbot - AI assistant gateway for Telegram
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

  # Check if secrets exist
  telegramTokenAgeFile = "${private}/home/common/ai/resources/clawdbot/telegram-bot-token.age";
  anthropicKeyAgeFile = "${private}/home/common/ai/resources/clawdbot/anthropic-api-key.age";
  secretsExist = builtins.pathExists telegramTokenAgeFile && builtins.pathExists anthropicKeyAgeFile;

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
    # AI model defaults
    defaults = {
      model = "anthropic/claude-sonnet-4-20250514"; # Fast and capable
      thinkingDefault = "medium";
    };

    # First-party plugins (all enabled as requested)
    firstParty = {
      summarize.enable = true; # Summarize web pages, PDFs, videos
      peekaboo.enable = true; # Take screenshots
      oracle.enable = true; # Web search
      poltergeist.enable = true; # Control macOS UI
      sag.enable = true; # Text-to-speech
      camsnap.enable = true; # Camera snapshots
      gogcli.enable = true; # Google Calendar
      bird.enable = true; # Twitter/X
      sonoscli.enable = true; # Sonos control
      imsg.enable = true; # iMessage
    };

    # Exclude tools we already have configured elsewhere
    excludeTools = [ "git" "jq" "ripgrep" ];

    # Use named instance to get proper defaults for all nested options
    instances.default = {
      enable = true;

      # Anthropic API key
      providers.anthropic.apiKeyFile = anthropicKeyPath;

      # Telegram provider
      providers.telegram = {
        enable = true;
        botTokenFile = telegramTokenPath;
        # Telegram user IDs allowed to interact with the bot
        # Get your ID by messaging @userinfobot on Telegram
        allowFrom = [
          28814201 # @kamushadenes
        ];
      };
    };
  };

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
