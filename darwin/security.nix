{ config, ... }:

{
  # Casks
  homebrew.casks = [
    "1password"
    "burp-suite"
    #"malwarebytes"
    "ngrok"
    "qflipper"
    "wireshark-app"
    #"yubico-yubikey-manager"
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
        ${config.users.users.homebrew.name} ALL=(ALL:ALL) ALL
        ${config.users.users.kamushadenes.name} ALL=(ALL) NOPASSWD: /usr/bin/env * nix build --no-link --profile /nix/var/nix/profiles/system *
        ${config.users.users.kamushadenes.name} ALL=(ALL) NOPASSWD: /usr/bin/env * */darwin-rebuild activate
      '';
    };
  };

  networking = {
    applicationFirewall = {
      enable = true;
      enableStealthMode = true;
    };
  };

  system = {
    defaults = {
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
