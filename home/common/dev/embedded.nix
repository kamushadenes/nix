{ pkgs, pkgs-unstable, ... }:
{
  home.packages = with pkgs; [
    avrdude
    platformio
    pyocd
    pkgs-unstable.mtkclient
    edl
  ];
}
