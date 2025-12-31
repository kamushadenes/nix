{ pkgs, ... }:
let
  fontsCommon = import ../shared/fonts-common.nix { inherit pkgs; };
in
{
  fonts = {
    packages = fontsCommon.common ++ fontsCommon.nixos;
  };
}
