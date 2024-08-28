{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    discord
    signal-desktop
    slack
    teamviewer
    zoom-us
  ];
}
