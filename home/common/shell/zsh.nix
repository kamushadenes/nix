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
      (lib.mkIf pkgs.stdenv.isDarwin (lib.mkBefore ''
        # Increase key timeout for escape sequences
        KEYTIMEOUT=30
      ''))

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
    ];
  };
}
