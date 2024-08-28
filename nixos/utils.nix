{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    qbittorrent
    steam
    uhk-agent
    uhk-udev-rules
  ];
}
