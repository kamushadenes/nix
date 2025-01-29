{
  config,
  pkgs-unstable,
  ...
}:
{
  programs = {
    ghostty = {
      enable = true;
      package = pkgs-unstable.ghostty;

      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;
      enableFishIntegration = config.programs.fish.enable;

      installBatSyntax = config.programs.bat.enable;
      installVimSyntax = true;

      settings = {
        theme = "catppuccin-macchiato";
      };
    };
  };
}
