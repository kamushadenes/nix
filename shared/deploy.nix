# Node configuration for deployment tool
# Generates JSON config consumed by deploy.py
{ lib, pkgs }:
let
  # Machine definitions - single source of truth for deployment targets
  # Keep in sync with flake.nix darwinConfigurations and nixosConfigurations
  #
  # Note: local vs remote is determined at runtime by comparing current hostname.
  # targetHosts is a list of hosts/IPs to try in order until one succeeds.
  machines = {
    # Darwin (macOS) machines - all aarch64-darwin
    studio = {
      type = "darwin";
      role = "workstation";
    };
    macbook-m3-pro = {
      type = "darwin";
      role = "workstation";
    };
    w-henrique = {
      type = "darwin";
      role = "workstation";
    };

    # NixOS machines - all x86_64-linux
    nixos = {
      type = "nixos";
      role = "workstation";
    };
    aether = {
      type = "nixos";
      role = "headless";
      # Multiple hosts to try in order (tailscale, LAN, etc.)
      targetHosts = [ "aether" ];
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
    # Default to node name if no targetHosts specified
    targetHosts = cfg.targetHosts or [ name ];
    buildHost = cfg.buildHost or name;
  }) machines;

in
{
  inherit nodes;
  # JSON representation for Python script substitution
  configJson = builtins.toJSON { inherit nodes; };
}
