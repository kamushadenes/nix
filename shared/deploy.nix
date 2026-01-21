# Node configuration for deployment tool
# Generates JSON config consumed by deploy.py
{ lib, pkgs, private ? null }:
let
  # Private hosts to merge (from private submodule)
  # These are prepended to the public targetHosts
  privateHosts = if private != null && builtins.pathExists "${private}/deploy-hosts.nix"
    then import "${private}/deploy-hosts.nix"
    else {};

  # Machine definitions - single source of truth for deployment targets
  # Keep in sync with flake.nix darwinConfigurations and nixosConfigurations
  #
  # Note: local vs remote is determined at runtime by comparing current hostname.
  # targetHosts is a list of hosts/IPs to try in order until one succeeds.
  # Order: Local IPs (from privateHosts) -> Tailscale -> DNS short names -> FQDN -> Public IPs
  machines = {
    # Darwin (macOS) machines - all aarch64-darwin
    # IPs are loaded from privateHosts
    studio = {
      type = "darwin";
      role = "workstation";
      targetHosts = [ "studio" "studio.hyades.io" ];
    };
    macbook-m3-pro = {
      type = "darwin";
      role = "workstation";
      targetHosts = [ "macbook-m3-pro" "macbook-m3-pro.hyades.io" ];
    };
    w-henrique = {
      type = "darwin";
      role = "workstation";
      targetHosts = [ "w-henrique" "w-henrique.hyades.io" ];
    };

    # NixOS machines - all x86_64-linux
    nixos = {
      type = "nixos";
      role = "workstation";
      targetHosts = [ "nixos" "nixos.hyades.io" ];
    };
    aether = {
      type = "nixos";
      role = "headless";
      # IPs loaded from privateHosts
      targetHosts = [ "aether" "aether.hyades.io" ];
      sshPort = 5678;
    };
  };

  # Generate tags for a node based on its configuration
  mkTags = name: cfg:
    [ "@${cfg.type}" "@${cfg.role}" ];

  # Merge private hosts with public hosts
  # Private hosts are prepended (tried first)
  mergeHosts = name: publicHosts:
    (privateHosts.${name} or []) ++ publicHosts;

  # Transform machine configs into node configs with computed tags
  nodes = lib.mapAttrs (name: cfg: {
    inherit (cfg) type role;
    tags = mkTags name cfg;
    targetHosts = mergeHosts name (cfg.targetHosts or [ name ]);
    buildHost = cfg.buildHost or name;
    sshPort = cfg.sshPort or 22;
  }) machines;

in
{
  inherit nodes;
  # JSON representation for Python script substitution
  configJson = builtins.toJSON { inherit nodes; };
}
