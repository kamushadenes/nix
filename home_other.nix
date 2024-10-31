{
  config,
  inputs,
  pkgs,
  pkgs-unstable,
  lib,
  osConfig,
  system,
  ...
}:
{
  nixpkgs.config.allowUnfree = true;

  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      enableVteIntegration = true;
      initExtra = lib.mkMerge [
        (lib.optionals pkgs.stdenv.isDarwin ''
          path+=('${osConfig.homebrew.brewPrefix}')
          export PATH

          unalias brew 2>/dev/null
          brewser=$(stat -f "%Su" $(which brew))
          alias brew="sudo -Hu $brewser brew"
        '')
      ];
    };
  };

  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
}
