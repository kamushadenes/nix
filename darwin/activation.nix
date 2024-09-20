{ pkgs, packages, ... }:
{

  activationScripts = {
    autoSmb = {
      enable = true;
      text = ''
        source ${packages.colorScript}
        _iNote "Enabling auto_smb"

        /usr/bin/sudo /run/current-system/sw/bin/enable_auto_smb
      '';
    };

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
}
