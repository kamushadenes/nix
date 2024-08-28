{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs = {
    nix-index = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;
      enableFishIntegration = config.programs.fish.enable;
    };
  };

  home.packages = with pkgs; [
    devbox
    nix-search-cli
    nix-tree
    nixpkgs-fmt
    nurl
  ];

  manual.manpages.enable = false;
  programs.man.enable = false;
}
