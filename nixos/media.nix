{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    audacity
    gimp
    handbrake
    vlc
  ];
}
