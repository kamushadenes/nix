{
  config,
  pkgs,
  lib,
  osConfig,
  helpers,
  ...
}:
{
  home.packages = with pkgs; [ jankyborders ];

  xdg.configFile = lib.mkIf pkgs.stdenv.isDarwin {
    "bettertouchtool/default_preset.json" = {
      source = ./resources/bettertouchtool/Default.bttpreset;
    };
  };
}
