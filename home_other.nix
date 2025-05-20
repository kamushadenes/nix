{
  pkgs,
  lib,
  osConfig,
  ...
}:
{
  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      enableVteIntegration = true;
      initContent = lib.mkMerge [
        (lib.optionals pkgs.stdenv.isDarwin ''
          path+=('${osConfig.homebrew.brewPrefix}')
          export PATH
        '')
      ];
    };
    bash = {
      enable = true;
      enableCompletion = true;
      enableVteIntegration = true;
    };
  };

  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
}
