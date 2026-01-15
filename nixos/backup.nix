{ config, ... }:
{
  # Resilio Sync service
  services.resilio = {
    enable = true;
    enableWebUI = true;
    httpListenAddr = "127.0.0.1";
    httpListenPort = 8888;
    # Run as the main user to access their files
    user = config.users.users.kamushadenes.name;
    group = config.users.users.kamushadenes.group;
  };

  # Open firewall ports for Resilio Sync
  networking.firewall = {
    allowedTCPPorts = [ 8888 ]; # Web UI (localhost only via reverse proxy if needed)
    allowedUDPPorts = [ 3838 ]; # Resilio listening port
  };
}
