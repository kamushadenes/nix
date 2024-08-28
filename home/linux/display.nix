{
  config,
  pkgs,
  lib,
  globalVariables,
  ...
}:
{
  dconf = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };

  home = lib.mkIf pkgs.stdenv.isLinux {
    pointerCursor = {
      name = "Adwaita";
      package = pkgs.gnome.adwaita-icon-theme;
      size = 24;
      x11 = {
        enable = true;
        defaultCursor = "Adwaita";
      };
    };
  };

  wayland = lib.mkIf pkgs.stdenv.isLinux {
    windowManager.sway = {
      enable = true;
      config = rec {
        modifier = "Mod4";
        terminal = "alacritty";
        startup = [ { command = "firefox"; } ];
      };

      systemd = {
        enable = true;
        variables = builtins.attrNames globalVariables/base;
      };
    };
  };

  xsession = lib.mkIf pkgs.stdenv.isLinux { profileExtra = globalVariables.shell; };
}
