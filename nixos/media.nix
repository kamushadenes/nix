{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    audacity
    celluloid # mpv frontend (IINA alternative)
    gimp
    handbrake
    spotify
    vlc
  ];
}
