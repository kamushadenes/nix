{ pkgs, packages, ... }:
{

  system = {
    activationScripts = {
      postUserActivation = {
        text = ''
          source ${packages.colorScript}
          _iNote "Activating settings"

          /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
        '';
      };

      restartDock = {
        text = ''
          source ${packages.colorScript}
          _iNote "Restarting Dock"

          /usr/bin/killall Dock
        '';
      };
    };
  };
}
