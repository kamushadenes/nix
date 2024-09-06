{
  config,
  pkgs,
  lib,
  packages,
  ...
}:
{
  home.packages =
    with pkgs;
    lib.mkIf pkgs.stdenv.isDarwin [
      lua
      sketchybar
    ];

  xdg.configFile = lib.mkIf pkgs.stdenv.isDarwin {
    sketchybar = {
      source = ./resources/sketchybar;
      recursive = true;
    };
  };

  home.file = lib.mkIf pkgs.stdenv.isDarwin {
    ".local/share/sketchybar_lua/sketchybar.so".source = "${packages.sbarlua}/sketchybar.so";
  };
}
