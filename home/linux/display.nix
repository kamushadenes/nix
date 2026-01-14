{
  pkgs,
  lib,
  helpers,
  ...
}:
{
  dconf = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    settings = {
      # Interface (dark mode, 24h clock)
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "Adwaita-dark";
        clock-format = "24h";
        clock-show-weekday = true;
        enable-hot-corners = true;
        font-antialiasing = "rgba";
        font-hinting = "slight";
      };

      # Keyboard (key repeat: Darwin KeyRepeat=5, InitialKeyRepeat=30)
      # Darwin uses 15ms multiplier, so KeyRepeat=5 -> 75ms, InitialKeyRepeat=30 -> 450ms
      "org/gnome/desktop/peripherals/keyboard" = {
        delay = lib.hm.gvariant.mkUint32 450;
        repeat-interval = lib.hm.gvariant.mkUint32 75;
        repeat = true;
      };

      # Touchpad (tap-to-click, two-finger scroll)
      "org/gnome/desktop/peripherals/touchpad" = {
        tap-to-click = true;
        two-finger-scrolling-enabled = true;
        natural-scroll = true;
        speed = 0.5;
      };

      # Nautilus (path bar, list view)
      "org/gnome/nautilus/preferences" = {
        always-use-location-entry = true;
        default-folder-viewer = "list-view";
      };

      "org/gnome/nautilus/list-view" = {
        default-zoom-level = "small";
        use-tree-view = true;
      };

      # Window management
      "org/gnome/mutter" = {
        edge-tiling = true;
        dynamic-workspaces = true;
        workspaces-only-on-primary = false;
      };

      "org/gnome/desktop/wm/preferences" = {
        focus-mode = "click";
        button-layout = "appmenu:minimize,maximize,close";
      };

      # Privacy (auto-delete trash after 30 days)
      "org/gnome/desktop/privacy" = {
        remove-old-trash-files = true;
        remove-old-temp-files = true;
        old-files-age = lib.hm.gvariant.mkUint32 30;
        remember-recent-files = true;
        recent-files-max-age = 30;
      };

      # Screen lock
      "org/gnome/desktop/screensaver" = {
        lock-enabled = true;
        lock-delay = lib.hm.gvariant.mkUint32 0;
      };

      "org/gnome/desktop/session" = {
        idle-delay = lib.hm.gvariant.mkUint32 300;
      };

      # Power settings
      "org/gnome/settings-daemon/plugins/power" = {
        power-button-action = "suspend";
        sleep-inactive-ac-type = "nothing";
      };

      # Night light
      "org/gnome/settings-daemon/plugins/color" = {
        night-light-enabled = true;
        night-light-schedule-automatic = true;
        night-light-temperature = lib.hm.gvariant.mkUint32 3500;
      };

      # Notifications
      "org/gnome/desktop/notifications" = {
        show-banners = true;
        show-in-lock-screen = false;
      };
    };
  };

  home = lib.mkIf pkgs.stdenv.isLinux {
    pointerCursor = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
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
      config = {
        modifier = "Mod4";
        terminal = "alacritty";
        startup = [ { command = "firefox"; } ];
      };

      systemd = {
        enable = true;
        variables = builtins.attrNames helpers.globalVariables.base;
      };
    };
  };

  xsession = lib.mkIf pkgs.stdenv.isLinux { profileExtra = helpers.globalVariables.shell; };
}
