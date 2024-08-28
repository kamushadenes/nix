{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    avrdude
    platformio
  ];
}
