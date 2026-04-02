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
  # Add direnv hook to .profile for non-interactive shells (Claude Code)
  # Use programs.bash.profileExtra instead of home.sessionVariablesExtra to avoid
  # home-manager translating this bash-specific code to Fish (where it breaks
  # because Fish's VAR=cmd syntax needs `env` and `direnv export bash` outputs
  # bash syntax, not Fish syntax).
  programs.bash.profileExtra = lib.mkIf config.programs.direnv.enable ''
    if [ -n "$CLAUDECODE" ]; then
      eval "$(DIRENV_LOG_FORMAT= ${lib.getExe config.programs.direnv.package} export bash)"
    fi
  '';

  programs.bash = {
    enable = true;
    enableCompletion = true;
    enableVteIntegration = true;

    sessionVariables = helpers.globalVariables.base;

    shellAliases = shellCommon.aliases;

    initExtra = lib.mkMerge [
      # Functions from shell-common
      shellCommon.bashZsh.functions
      shellCommon.bashZsh.flushdns
      shellCommon.bashZsh.help

      # PATH additions
      ''
        ${shellCommon.bash.pathSetup}

        # Global Variables
        ${helpers.globalVariables.shell}
      ''

      # SSH key loading
      shellCommon.bashZsh.sshKeyLoading

      # Homebrew init (Darwin)
      shellCommon.bashZsh.homebrewInit

      # Ghostty shell integration
      shellCommon.bashZsh.ghosttyIntegration.bash

      # Navi widget
      (lib.mkIf config.programs.navi.enable ''
        eval "$(${lib.getExe pkgs.navi} widget bash)"
      '')

      # Worktrunk shell integration (enables wt switch to change directory)
      ''
        if command -v wt &>/dev/null; then
          eval "$(wt config shell init bash 2>/dev/null)"
        fi
      ''
    ];
  };
}
