{ pkgs, ... }:

{
  programs = {
    dconf = {
      enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    gnome.adwaita-icon-theme
    gnomeExtensions.appindicator
    gnome.gnome-settings-daemon
  ];

  services = {
    dbus = {
      packages = with pkgs; [ gnome2.GConf ];
    };

    gnome = {
      gnome-keyring = {
        enable = true;
      };
    };

    xserver = {
      enable = true;
      displayManager = {
        gdm = {
          enable = true;
        };
      };

      desktopManager = {
        gnome = {
          enable = true;
        };
      };
    };
  };

  environment.gnome.excludePackages =
    (with pkgs; [
      # for packages that are pkgs.*
      gnome-tour
      gnome-connections
    ])
    ++ (with pkgs.gnome; [
      epiphany # web browser
      geary # email reader
      evince # document viewer
    ]);
}
