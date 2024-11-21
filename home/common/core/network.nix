{ pkgs, ... }:
{
  home.packages = with pkgs; [
    cloudflared
    curl
    inetutils
    iperf3
    magic-wormhole
    netcat-gnu
    rclone
    rsync
    socat
    speedtest-cli
    wget
  ];
}
