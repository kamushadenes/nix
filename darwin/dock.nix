{
  config,
  pkgs,
  packages,
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
        expose-group-by-app = true;

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
          "/Applications/Hoppscotch.app"
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
  };
}
