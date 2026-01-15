{ config, ... }:
let
  storagePath = "/home/kamushadenes/.config/resilio-sync";
in
{
  # Resilio Sync service
  services.resilio = {
    enable = true;
    enableWebUI = true;
    httpListenAddr = "127.0.0.1";
    httpListenPort = 8888;
    deviceName = config.networking.hostName;
    inherit storagePath;
    directoryRoot = "/home/kamushadenes";
  };

  # Ensure storage directory exists
  systemd.tmpfiles.rules = [
    "d ${storagePath} 0755 rslsync rslsync -"
  ];

  # Resilio runs as rslsync user, add kamushadenes to rslsync group for shared access
  users.users.kamushadenes.extraGroups = [ "rslsync" ];

  # Open firewall ports for Resilio Sync
  networking.firewall = {
    allowedTCPPorts = [ 8888 ]; # Web UI (localhost only via reverse proxy if needed)
    allowedUDPPorts = [ 3838 ]; # Resilio listening port
  };
}
