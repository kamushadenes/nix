{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    android-tools
    apktool
    #jadx
  ];
}
