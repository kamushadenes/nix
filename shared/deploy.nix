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
  # Order: Private IPs -> Tailscale IP (works anywhere) -> .hyades.io (local network) -> hostname
  machines = {
    # Darwin (macOS) machines - all aarch64-darwin
    studio = {
      type = "darwin";
      role = "workstation";
      # Tailscale: kamus-mac-studio
      targetHosts = [ "REDACTED_TS_IP" "studio.hyades.io" "studio" ];
    };
    macbook-m3-pro = {
      type = "darwin";
      role = "workstation";
      targetHosts = [ "REDACTED_TS_IP" "macbook-m3-pro.hyades.io" "macbook-m3-pro" ];
    };
    w-henrique = {
      type = "darwin";
      role = "workstation";
      targetHosts = [ "REDACTED_TS_IP" "w-henrique.hyades.io" "w-henrique" ];
    };

    # NixOS machines - all x86_64-linux
    nixos = {
      type = "nixos";
      role = "workstation";
      # No tailscale entry found - using hostname only
      targetHosts = [ "nixos.hyades.io" "nixos" ];
    };
    aether = {
      type = "nixos";
      role = "headless";
      targetHosts = [ "REDACTED_TS_IP" "aether.hyades.io" "aether" ];
      buildHost = "aether";
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
