# Moltbot - AI assistant gateway for Telegram
#
# Uses fork (github:kamushadenes/nix-moltbot) with fixes for:
#   - byProvider -> byChannel (routing config)
#   - telegram at root -> channels.telegram
#
# Uses nix-moltbot for declarative configuration.
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
  secretsDir = "${homeDir}/.moltbot/secrets";

  enabled = true;

  # Create minimal wrapper with only the moltbot binary
  # Full moltbot package bundles entire shell environment (bash, python, gotools, etc.)
  # which conflicts with system packages
  moltbotMinimal = pkgs.runCommand "moltbot-minimal" { } ''
    mkdir -p $out/bin
    # Only symlink the moltbot binary, not the entire bundled environment
    ln -s ${pkgs.moltbot}/bin/moltbot $out/bin/moltbot
  '';

  # Check if secrets exist
  telegramTokenAgeFile = "${private}/home/common/ai/resources/clawdbot/telegram-bot-token.age";
  anthropicKeyAgeFile = "${private}/home/common/ai/resources/clawdbot/anthropic-api-key.age";
  secretsExist = enabled && builtins.pathExists telegramTokenAgeFile && builtins.pathExists anthropicKeyAgeFile;

  # Agenix secrets paths (decrypted at runtime)
  telegramTokenPath = "${secretsDir}/telegram-bot-token";
  anthropicKeyPath = "${secretsDir}/anthropic-api-key";
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
  };

  # Use instances API for proper configuration
  programs.moltbot = lib.mkIf secretsExist {
    # Use filtered full package (excludes idle binary that conflicts with system Python)
    # Full package needed for memory-core plugin
    package = moltbotMinimal;

    # Don't expose plugin packages to avoid conflicts
    exposePluginPackages = false;

    # AI model defaults
    defaults = {
      model = "anthropic/claude-sonnet-4-20250514"; # Fast and capable
      thinkingDefault = "medium";
    };

    # First-party plugins
    # NOTE: Currently disabled - upstream nix-steipete-tools doesn't export moltbotPlugin
    # TODO: Re-enable when upstream plugin format is fixed
    firstParty = {
      summarize.enable = false;
      peekaboo.enable = false;
      oracle.enable = false;
      poltergeist.enable = false;
      sag.enable = false;
      camsnap.enable = false;
      gogcli.enable = false;
      bird.enable = false;
      sonoscli.enable = false;
      imsg.enable = false;
    };

    # Use named instance to get proper defaults for all nested options
    instances.default = {
      enable = true;

      # Use filtered full package at instance level too
      package = moltbotMinimal;

      # Anthropic API key
      providers.anthropic.apiKeyFile = anthropicKeyPath;

      # Telegram provider (now works with fixed module)
      providers.telegram = {
        enable = true;
        botTokenFile = telegramTokenPath;
        allowFrom = [ 28814201 ]; # @kamushadenes
      };

      # Disable memory plugin (set to "none" per moltbot docs)
      # Set gateway auth token for local access
      configOverrides = {
        plugins.slots.memory = "none";
        gateway.auth.token = "local-gateway-token";
      };
    };
  };

  # Create .env file for moltbot with API key from agenix-decrypted secret
  # This runs after agenix decrypts the secrets
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
      echo "YOUR_TELEGRAM_BOT_TOKEN" | agenix -e home/common/ai/resources/clawdbot/telegram-bot-token.age
      echo "YOUR_ANTHROPIC_API_KEY" | agenix -e home/common/ai/resources/clawdbot/anthropic-api-key.age
    Then update allowFrom in home/common/ai/clawdbot.nix with your Telegram user ID.
  '';
}
