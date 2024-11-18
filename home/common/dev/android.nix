{
  pkgs,
  pkgs-unstable,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    android-tools
    pkgs-unstable.apktool
    pkgs-unstable.jadx
  ];
}
