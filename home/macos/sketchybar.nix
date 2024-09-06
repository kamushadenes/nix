{
  config,
  pkgs,
  lib,
  ...
}:
{
  xdg.configFile = lib.mkIf pkgs.stdenv.isDarwin {
    sketchybar = {
      source = ./resources/sketchybar;
    };
  };
}
