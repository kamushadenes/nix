# Node configuration for deployment tool
# Generates JSON config consumed by deploy.py
{ lib, pkgs }:
let
  # Machine definitions - single source of truth for deployment targets
  # Keep in sync with flake.nix darwinConfigurations and nixosConfigurations
  machines = {
    # Darwin (macOS) machines - all aarch64-darwin
    studio = {
      type = "darwin";
      role = "workstation";
      local = true;
    };
    macbook-m3-pro = {
      type = "darwin";
      role = "workstation";
      local = true;
    };
    w-henrique = {
      type = "darwin";
      role = "workstation";
      local = true;
    };

    # NixOS machines - all x86_64-linux
    nixos = {
      type = "nixos";
      role = "workstation";
      local = true;
    };
    aether = {
      type = "nixos";
      role = "headless";
      local = false;
      targetHost = "aether";
      buildHost = "aether";
    };
  };

  # Generate tags for a node based on its configuration
  mkTags = name: cfg:
    [ "@${cfg.type}" "@${cfg.role}" ]
    ++ lib.optional cfg.local "@local"
    ++ lib.optional (!cfg.local) "@remote";

  # Transform machine configs into node configs with computed tags
  nodes = lib.mapAttrs (name: cfg: {
    inherit (cfg) type role local;
    tags = mkTags name cfg;
    targetHost = cfg.targetHost or null;
    buildHost = cfg.buildHost or null;
  }) machines;

in
{
  inherit nodes;
  # JSON representation for Python script substitution
  configJson = builtins.toJSON { inherit nodes; };
}
