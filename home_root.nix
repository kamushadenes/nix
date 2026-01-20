# Minimal home-manager configuration for root user
# Used primarily to provide SSH config for nix remote builds
{
  config,
  lib,
  pkgs,
  private,
  ...
}:
let
  # Path to kamushadenes' SSH identity (root can read any file)
  userIdentityPath = "/var/folders/jl/yb1gyxfs0gx15sjsjp2zt5w40000gn/T/agenix/id_ed25519.age";
in
{
  home.stateVersion = "25.11";
  home.username = lib.mkForce "root";
  home.homeDirectory = lib.mkForce "/var/root";

  programs.ssh = {
    enable = true;
    matchBlocks = {
      # Aether IPs - for deployment fallback
      "aether-ips" = {
        host = "REDACTED_IP REDACTED_IPV6 REDACTED_TS_IP";
        port = 5678;
        user = "kamushadenes";
        identitiesOnly = true;
        identityFile = userIdentityPath;
      };

      # Aether server - main entry for remote builds
      "aether" = {
        host = "aether aether.hyades.io";
        hostname = "REDACTED_IP";
        port = 5678;
        user = "kamushadenes";
        identitiesOnly = true;
        identityFile = userIdentityPath;
      };

      # Default settings
      "*" = {
        host = "*";
        identitiesOnly = true;
        identityFile = userIdentityPath;
        compression = true;
        controlMaster = "no";
        serverAliveInterval = 10;
        serverAliveCountMax = 2;
        hashKnownHosts = true;
        extraOptions = {
          "StrictHostKeyChecking" = "accept-new";
        };
      };
    };
  };
}
