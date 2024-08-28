{ pkgs, ... }:

{
  # Casks
  homebrew.casks = [ "capslocknodelay" ];

  launchd.user.agents.capslocknodelay = {
    serviceConfig.ProgramArguments = [ "/Applications/CapsLockNoDelay.app" ];
    serviceConfig.RunAtLoad = true;
  };
}
