# Node configuration for deployment tool
# Reads from private/nodes.json (single source of truth) and generates config for deploy.py
{ lib, pkgs, private ? null }:
let
  # Read nodes from private JSON file
  nodesJson = builtins.fromJSON (builtins.readFile "${private}/nodes.json");

  # Generate tags for a node based on its configuration
  mkTags = name: cfg:
    [ "@${cfg.type}" "@${cfg.role}" ];

  # Transform machine configs into node configs with computed tags
  nodes = lib.mapAttrs (name: cfg: {
    inherit (cfg) type role;
    tags = mkTags name cfg;
    targetHosts = cfg.targetHosts or [ name ];
    buildHost = cfg.buildHost or name;
    sshPort = cfg.sshPort or 22;
    user = cfg.user or null;  # SSH user override (e.g., "root" for minimal role containers)
  }) nodesJson.nodes;

in
{
  inherit nodes;
  # JSON representation for Python script substitution (legacy, kept for compatibility)
  configJson = builtins.toJSON { inherit nodes; };
}
