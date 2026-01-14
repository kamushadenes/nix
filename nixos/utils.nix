{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    clickup
    gitkraken
    mqtt-explorer
    obsidian
    qbittorrent
    remmina # NoMachine alternative
    uhk-agent
    uhk-udev-rules
    xpipe
  ];
}
