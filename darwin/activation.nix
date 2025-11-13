{ packages, ... }:
{

  system = {
    activationScripts = {
      reloadSettings = {
        text = ''
          shellcheck disable=SC1091
          source ${packages.colorScript}
          _iNote "Activating settings"

          sudo -u kamushadenes -- /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
        '';
      };
      /*
        fixSketchybar = {
          text = ''
            shellcheck disable=SC1091
            source ${packages.colorScript}
            _iNote "Fixing sketchybar"

            #/opt/homebrew/bin/brew services start sketchybar --sudo-service-user kamushadenes
            chown -R kamushadenes g+w /opt/homebrew/var/log/sketchybar
            sudo -u kamushadenes brew services start sketchybar
          '';
        };
      */
    };
  };
}
