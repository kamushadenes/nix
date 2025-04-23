{
  pkgs-unstable,
  ...
}:
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
        expose-group-apps = true;

        # Bottom right hot corner action = Lock Screen (13)
        wvous-br-corner = 13;

        persistent-apps = [
          "/System/Applications/Launchpad.app"
          "/Applications/Arc.app"
          #"/Applications/Orion.app"
          #"/System/Applications/Mail.app"
          "/Applications/Setapp/Canary Mail.app"
          "/Applications/Slack.app"
          "/System/Applications/Notes.app"
          "/Applications/Todoist.app"
          "/Applications/ClickUp.app"
          "/System/Applications/Calendar.app"
          "/Applications/Ghostty.app"
          #"${pkgs-unstable.kitty}/Applications/kitty.app"
          #"${pkgs-unstable.emacs30-pgtk}/Applications/Emacs.app"
          #"${pkgs-unstable.neovide}/Applications/Neovide.app"
          "/Applications/Visual Studio Code.app"
          "/Applications/Camo Studio.app"
          "/Applications/Screen Studio.app"
          "/Applications/Portal.app"
          "/Applications/Spotify.app"
          "/System/Applications/App Store.app"
          "/System/Applications/System Settings.app"
        ];
      };
    };
  };
}
