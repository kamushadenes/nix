{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    ffmpeg
    imagemagick
    graphviz
    exiftool
  ];
}
