{
  config,
  pkgs,
  lib,
  osConfig,
  packages,
  ...
}:
{
  xdg.configFile = lib.mkIf pkgs.stdenv.isDarwin {
    sketchybar = {
      source = ./resources/sketchybar;
    };

    "hm/dynamic-island-sketchybar" = {
      source = pkgs.fetchFromGitHub {
        owner = "crissNb";
        repo = "Dynamic-Island-Sketchybar";
        rev = "f9d3e973d0ef1197ccda2672437d89020acb99a5";
        hash = "sha256-29afB666p+993PKy+RKDzqdPd/X00BSNFq+06OHlliY=";
      };

      onChange = ''
        mkdir -p ${config.xdg.configHome}/dynamic-island-sketchybar 2>/dev/null
        ${lib.getExe pkgs.rsync} -rptgoL --delete ${config.xdg.configHome}/hm/dynamic-island-sketchybar/ ${config.xdg.configHome}/dynamic-island-sketchybar/
        chmod -R u+w ${config.xdg.configHome}/dynamic-island-sketchybar
      '';
    };

    "dynamic-island-sketchybar/userconfig.sh" = {
      source = ./resources/sketchybar/userconfig.sh;
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

  home.packages = with pkgs; [
    blueutil
    # python312Packages.bleak # currently broken on Darwin
    (writeScriptBin "dynamic-island-sketchybar" ''
      #!/bin/bash
      exec -a "$0" ${osConfig.homebrew.brewPrefix}/sketchybar $@
    '')
  ];
}
