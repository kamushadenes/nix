# Hardware configuration for tailscale-pve2 LXC
# Proxmox LXC container running Tailscale subnet router on pve2
# TODO: Create LXC and configure secrets before deploying
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

  networking.hostName = "tailscale-pve2";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # TODO: Create secrets directory and tailscaled-state.age for this node
  # Each node needs to be authenticated separately with its own auth key:
  #   1. Create LXC on pve2: /new-lxc tailscale-pve2 --tun=true ...
  #   2. Get SSH host key from new LXC
  #   3. Create auth key in Tailscale admin console
  #   4. Create secret: echo '{}' | age -r "machine_key" -r "main_key" > tailscaled-state.age
  #   5. Or migrate existing state from another node
  #
  # Uncomment after creating secrets:
  # age.secrets."tailscaled-state" = {
  #   file = "${private}/nixos/secrets/tailscale-pve2/tailscaled-state.age";
  #   path = "/var/lib/tailscale/tailscaled.state";
  #   owner = "root";
  #   group = "root";
  #   mode = "0600";
  # };
  #
  # systemd.services.tailscaled = {
  #   after = [ "agenix.service" ];
  #   wants = [ "agenix.service" ];
  # };
}
