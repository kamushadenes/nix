{
  config,
  pkgs,
  lib,
  osConfig,
  ...
}:
{
  xdg.configFile = lib.mkIf pkgs.stdenv.isDarwin {
    sketchybar = {
      source = ./resources/sketchybar;
    };
  };

  home.packages = with pkgs; [
    blueutil
    ifstat-legacy
  ];
}
