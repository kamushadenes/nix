{ pkgs, ... }:

{
  # Casks
  homebrew.casks = [
    "1password"
    "burp-suite"
    "maltego"
    "malwarebytes"
    "ngrok"
    "qflipper"
    "wireshark"
    "yubico-yubikey-manager"
  ];

  security = {
    # Auth sudo with Touch ID
    pam.enableSudoTouchIdAuth = true;
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
