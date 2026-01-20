# Node configuration for deployment tool
# Generates JSON config consumed by deploy.py
{ lib, pkgs }:
let
  # Machine definitions - single source of truth for deployment targets
  # Keep in sync with flake.nix darwinConfigurations and nixosConfigurations
  #
  # Note: local vs remote is determined at runtime by comparing current hostname.
  # targetHosts is a list of hosts/IPs to try in order until one succeeds.
  # Tailscale IPs are preferred as they work across networks.
  machines = {
    # Darwin (macOS) machines - all aarch64-darwin
    studio = {
      type = "darwin";
      role = "workstation";
      # Tailscale: kamus-mac-studio
      targetHosts = [ "REDACTED_TS_IP" "studio" ];
    };
    macbook-m3-pro = {
      type = "darwin";
      role = "workstation";
      targetHosts = [ "REDACTED_TS_IP" "macbook-m3-pro" ];
    };
    w-henrique = {
      type = "darwin";
      role = "workstation";
      targetHosts = [ "REDACTED_TS_IP" "w-henrique" ];
    };

    # NixOS machines - all x86_64-linux
    nixos = {
      type = "nixos";
      role = "workstation";
      # No tailscale entry found - using hostname only
      targetHosts = [ "nixos" ];
    };
    aether = {
      type = "nixos";
      role = "headless";
      targetHosts = [ "REDACTED_TS_IP" "aether" ];
      buildHost = "aether";
    };
  };

  # Generate tags for a node based on its configuration
  mkTags = name: cfg:
    [ "@${cfg.type}" "@${cfg.role}" ];

  # Transform machine configs into node configs with computed tags
  nodes = lib.mapAttrs (name: cfg: {
    inherit (cfg) type role;
    tags = mkTags name cfg;
    targetHosts = cfg.targetHosts or [ name ];
    buildHost = cfg.buildHost or name;
  }) machines;

in
{
  inherit nodes;
  # JSON representation for Python script substitution
  configJson = builtins.toJSON { inherit nodes; };
}
