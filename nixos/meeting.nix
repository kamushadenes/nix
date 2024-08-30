{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    discord
    slack
    teamviewer
    zoom-us
  ];
}
