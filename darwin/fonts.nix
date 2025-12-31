{ pkgs, ... }:
let
  fontsCommon = import ../shared/fonts-common.nix { inherit pkgs; };
in
{
  fonts = {
    packages = fontsCommon.common ++ fontsCommon.darwin;
  };

  homebrew.casks = [
    "font-ligature-symbols"
    "font-sf-pro"
    "font-sf-mono"
    "font-sf-mono-for-powerline"
  ];
}
