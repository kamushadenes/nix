{ pkgs, ... }:
{
  home.packages = with pkgs; [
    ffmpeg
    imagemagick
    graphviz
    exiftool
    yt-dlp
  ];
}
