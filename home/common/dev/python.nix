{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    black
    python312Full
  ];

  programs.pyenv = {
    enable = true;

    enableBashIntegration = config.programs.bash.enable;
    enableZshIntegration = config.programs.zsh.enable;
    enableFishIntegration = config.programs.fish.enable;
  };
}
