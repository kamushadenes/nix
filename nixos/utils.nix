{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    qbittorrent
    uhk-agent
    uhk-udev-rules
  ];
}
