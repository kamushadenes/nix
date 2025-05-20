{ config, ... }:

{
  # Casks
  homebrew.casks = [
    "1password"
    "burp-suite"
    #"malwarebytes"
    "ngrok"
    "qflipper"
    "wireshark"
    "yubico-yubikey-manager"
  ];

  security = {
    # Auth sudo with Touch ID
    pam = {
      services = {
        sudo_local = {
          touchIdAuth = true;
        };
      };
    };

    sudo = {
      extraConfig = with config.users.users; ''
        %brewers ALL=(${config.users.users.homebrew.name}) NOPASSWD: ${config.homebrew.brewPrefix}/brew *
      '';
    };
  };

  system = {
    defaults = {
      # Application Firewall
      alf = {
        globalstate = 1;
        stealthenabled = 1;
      };

      # Screensaver
      screensaver = {
        askForPassword = true;
      };

      # Login window
      loginwindow = {
        GuestEnabled = false;
        PowerOffDisabledWhileLoggedIn = false;
        RestartDisabledWhileLoggedIn = false;
        ShutDownDisabledWhileLoggedIn = false;
      };

      # Enable quarantine for downloaded applications
      LaunchServices = {
        LSQuarantine = true;
      };

      # Enable automatic updates
      SoftwareUpdate = {
        AutomaticallyInstallMacOSUpdates = true;
      };
    };
  };
}
