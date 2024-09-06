{
  config,
  pkgs,
  lib,
  packages,
  ...
}:
{
  home.packages = with pkgs; [ sketchybar ];

  xdg.configFile = lib.mkIf pkgs.stdenv.isDarwin {
    sketchybar = {
      source = ./resources/sketchybar/sketchybarrc;
      recursive = true;
    };
    "sketchybar/helpers/menus" = {
      source = "${packages.tnixcdots}/menus";
    };
    "sketchybar/helpers/event_providers" = {
      source = "${packages.tnixcdots}/event_providers";
    };

  };

  home.file = lib.mkIf pkgs.stdenv.isDarwin {
    ".local/share/sketchybar_lua/sketchybar.so".source = "${packages.sbarlua}/sketchybar.so";
  };
}
