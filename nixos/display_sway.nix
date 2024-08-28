{ pkgs, ... }:

{
  security = {
    polkit = {
      enable = true;
    };

    pam = {
      services = {
        swaylock = { };
      };

      loginLimits = [
        {
          domain = "@users";
          item = "rtprio";
          type = "-";
          value = 1;
        }
      ];
    };
  };

  programs = {
    sway = {
      enable = true;
      wrapperFeatures.gtk = true;
    };

    light = {
      enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    dunst
    grim
    slurp
    wl-clipboard
    mako
  ];

  systemd.user.services.kanshi = {
    description = "kanshi daemon";
    serviceConfig = {
      Type = "simple";
      ExecStart = ''${pkgs.kanshi}/bin/kanshi -c kanshi_config_file'';
    };
  };
}
