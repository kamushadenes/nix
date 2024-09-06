{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.packages = with pkgs; lib.mkIf pkgs.stdenv.isDarwin [ sketchybar ];

  xdg.configFile = lib.mkIf pkgs.stdenv.isDarwin {
    sketchybar = {
      source = ./resources/sketchybar;
    };
  };
}
