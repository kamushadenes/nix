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

  home.file."weather_config.json" = {
    text = ''
      {
        "wttr": {
          "url": "https://wttr.in/",
          "location": "Sao+Paulo",
          "format": "format=2"
        }
      }
    '';
  };

  home.packages = with pkgs; [ blueutil ];
}
