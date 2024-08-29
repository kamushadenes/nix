{ pkgs, ... }:

{
  launchd.user.agents = {
    parcel = {
      serviceConfig.ProgramArguments = [ "/Applications/Parcel.app" ];
      serviceConfig.RunAtLoad = true;
    };
    passepartout = {
      serviceConfig.ProgramArguments = [ "/Applications/Passepartout.app" ];
      serviceConfig.RunAtLoad = true;
    };
    raycast = {
      serviceConfig.ProgramArguments = [ "/Applications/Raycast.app" ];
      serviceConfig.RunAtLoad = true;
    };
    todoist = {
      serviceConfig.ProgramArguments = [ "/Applications/Todoist.app" ];
      serviceConfig.RunAtLoad = true;
    };
  };
}
