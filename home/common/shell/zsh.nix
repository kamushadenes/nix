{
  config,
  pkgs,
  lib,
  osConfig,
  helpers,
  shellCommon,
  ...
}:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    sessionVariables = helpers.globalVariables.base;

    shellAliases = shellCommon.aliases;

    # Use initContent with mkBefore/mkAfter for proper ordering
    initContent = lib.mkMerge [
      # Early init (replaces initExtraFirst)
      (lib.mkIf pkgs.stdenv.isDarwin (
        lib.mkBefore ''
          # Increase key timeout for escape sequences
          KEYTIMEOUT=30
        ''
      ))

      # Functions from shell-common
      shellCommon.bashZsh.functions
      shellCommon.bashZsh.flushdns
      shellCommon.bashZsh.help

      # PATH additions
      ''
        ${shellCommon.zsh.pathSetup}

        # Global Variables
        ${helpers.globalVariables.shell}
      ''

      # OTEL secrets (endpoint + headers from agenix)
      ''
        if [ -f "$HOME/.config/opencode/secrets/otel-endpoint" ]; then
            export OPENCODE_OTLP_ENDPOINT="$(cat "$HOME/.config/opencode/secrets/otel-endpoint")"
            export OTEL_EXPORTER_OTLP_ENDPOINT="$(cat "$HOME/.config/opencode/secrets/otel-endpoint")"
        fi
        if [ -f "$HOME/.config/opencode/secrets/otel-headers" ]; then
            export OPENCODE_OTLP_HEADERS="$(cat "$HOME/.config/opencode/secrets/otel-headers")"
            export OTEL_EXPORTER_OTLP_HEADERS="$(cat "$HOME/.config/opencode/secrets/otel-headers")"
        fi
      ''

      # SSH key loading
      shellCommon.bashZsh.sshKeyLoading

      # Homebrew init (Darwin)
      shellCommon.bashZsh.homebrewInit

      # Ghostty shell integration
      shellCommon.bashZsh.ghosttyIntegration.zsh

      # Yazi keybind (Ctrl+F)
      (lib.mkIf config.programs.yazi.enable ''
        bindkey -s '^f' 'yazi\n'
      '')

      # Navi widget
      (lib.mkIf config.programs.navi.enable ''
        eval "$(${lib.getExe pkgs.navi} widget zsh)"
      '')

      # Worktrunk shell integration (enables wt switch to change directory)
      ''
        if command -v wt &>/dev/null; then
          eval "$(wt config shell init zsh 2>/dev/null)"
        fi
      ''
    ];
  };
}
