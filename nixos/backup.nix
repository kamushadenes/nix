{ config, lib, machine, ... }:
let
  # Use /var/lib for storage - NixOS service creates this automatically
  storagePath = "/var/lib/resilio-sync";
  # aether uses ephemeral root and needs persistence
  isEphemeral = machine == "aether";
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

  # Persist resilio data on ephemeral systems (aether)
  fileSystems."/var/lib/resilio-sync" = lib.mkIf isEphemeral {
    device = "/nix/persist/var/lib/resilio-sync";
    fsType = "none";
    options = [ "bind" ];
  };

  # Resilio runs as rslsync user, add kamushadenes to rslsync group for shared access
  users.users.kamushadenes.extraGroups = [ "rslsync" ];

  # Open firewall ports for Resilio Sync
  networking.firewall = {
    allowedTCPPorts = [ 8888 ]; # Web UI (localhost only via reverse proxy if needed)
    allowedUDPPorts = [ 3838 ]; # Resilio listening port
  };
}
