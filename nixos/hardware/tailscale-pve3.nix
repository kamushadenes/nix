# Hardware configuration for tailscale-pve3 LXC
# Proxmox LXC container running Tailscale subnet router on pve3
{ config, lib, pkgs, modulesPath, private, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../machines/tailscale.nix
  ];

  boot.isContainer = true;

  # Console configuration for LXC
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  systemd.services.console-getty.enable = true;

  networking.hostName = "tailscale-pve3";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Node-specific secret: tailscale state file
  # Each node has its own machine identity
  age.secrets."tailscaled-state" = {
    file = "${private}/nixos/secrets/tailscale-pve3/tailscaled-state.age";
    path = "/var/lib/tailscale/tailscaled.state";
    owner = "root";
    group = "root";
    mode = "0600";
  };

  # Ensure tailscaled starts after the state file is deployed
  systemd.services.tailscaled = {
    after = [ "agenix.service" ];
    wants = [ "agenix.service" ];
  };
}
