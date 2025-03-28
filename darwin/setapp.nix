{ ... }:

{
  # Casks
  homebrew.casks = [ "setapp" ];

  launchd.user.agents = {
    apptamer = {
      serviceConfig.ProgramArguments = [ "/Applications/Setapp/App Tamer.app" ];
      serviceConfig.RunAtLoad = true;
    };
    bartender = {
      serviceConfig.ProgramArguments = [ "/Applications/Setapp/Bartender.app" ];
      serviceConfig.RunAtLoad = true;
    };
    cleanshot = {
      serviceConfig.ProgramArguments = [ "/Applications/Setapp/CleanShot X.app" ];
      serviceConfig.RunAtLoad = true;
    };
    hazeover = {
      serviceConfig.ProgramArguments = [ "/Applications/Setapp/HazeOver.app" ];
      serviceConfig.RunAtLoad = true;
    };
    paste = {
      serviceConfig.ProgramArguments = [ "/Applications/Setapp/Paste.app" ];
      serviceConfig.RunAtLoad = true;
    };
    pixelsnap = {
      serviceConfig.ProgramArguments = [ "/Applications/Setapp/PixelSnap.app" ];
      serviceConfig.RunAtLoad = true;
    };
  };
}
