{ pkgs, ... }:

{
  imports = [ ../shared/shells.nix ];

  environment.systemPackages = with pkgs; [ sudo ];

  # Create /bin/bash symlink for scripts with #!/bin/bash shebang
  system.activationScripts.binbash = ''
    mkdir -p /bin
    ln -sfn ${pkgs.bash}/bin/bash /bin/bash
  '';
}
