{ config, ... }:
{
  # Resilio Sync service
  services.resilio = {
    enable = true;
    enableWebUI = true;
    httpListenAddr = "127.0.0.1";
    httpListenPort = 8888;
    # Storage path for sync data
    storagePath = "/home/kamushadenes/.config/resilio-sync";
    directoryRoot = "/home/kamushadenes";
  };

  # Resilio runs as rslsync user, add kamushadenes to rslsync group for shared access
  users.users.kamushadenes.extraGroups = [ "rslsync" ];

  # Open firewall ports for Resilio Sync
  networking.firewall = {
    allowedTCPPorts = [ 8888 ]; # Web UI (localhost only via reverse proxy if needed)
    allowedUDPPorts = [ 3838 ]; # Resilio listening port
  };
}
