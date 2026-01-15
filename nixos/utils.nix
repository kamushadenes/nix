{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    clickup
    gitkraken
    mqtt-explorer
    obsidian
    qbittorrent
    uhk-agent
    uhk-udev-rules
    xpipe
  ];
}
