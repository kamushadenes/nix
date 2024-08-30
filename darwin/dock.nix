{ config, pkgs, ... }:
let
  colorScript = builtins.fetchurl {
    url = "https://raw.githubusercontent.com/nix-community/home-manager/b3a9fb9d05e5117413eb87867cebd0ecc2f59b7e/lib/bash/home-manager.sh";
    sha256 = "90ea66d50804f355801cd8786642b46991fc4f4b76180f7a72aed02439b67d08";
  };
in
{
  system = {
    defaults = {
      # Dock
      dock = {
        autohide = true;
        launchanim = true;
        mineffect = "genie";
        minimize-to-application = true;
        orientation = "bottom";
        show-process-indicators = true;
        show-recents = false;

        # Bottom right hot corner action = Lock Screen (13)
        wvous-br-corner = 13;

        persistent-apps = [
          "/System/Applications/Launchpad.app"
          "/Applications/Arc.app"
          "/System/Applications/Mail.app"
          "/Applications/Discord.app"
          "/Applications/Slack.app"
          "/System/Applications/Notes.app"
          "/Applications/Todoist.app"
          "/Applications/ClickUp.app"
          "/System/Applications/Calendar.app"
          "${pkgs.kitty}/Applications/kitty.app"
          "${pkgs.emacs29-pgtk}/Applications/Emacs.app"
          "/Applications/Setapp/TypingMind.app"
          "/Applications/Camo Studio.app"
          "/Applications/Screen Studio.app"
          "/Applications/Portal.app"
          "/System/Applications/Music.app"
          "/System/Applications/App Store.app"
          "/System/Applications/System Settings.app"
        ];
      };
    };

    activationScripts = {
      restartDock = {
        text = ''
          source ${colorScript}
          _iNote "Restarting Dock"

          /usr/bin/killall Dock
        '';
      };
    };
  };
}
