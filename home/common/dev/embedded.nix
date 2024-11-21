{ pkgs, ... }:
{
  home.packages = with pkgs; [
    avrdude
    platformio
  ];
}
