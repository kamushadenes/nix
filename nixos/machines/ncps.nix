# Machine configuration for ncps LXC
# Nix Cache Proxy Server - local caching and signing for Nix binary cache
{ config, lib, pkgs, private, ... }:

{
  imports = [ "${private}/nixos/lxc-management.nix" ];

  # Agenix identity paths for secret decryption
  age.identityPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];

  # NFS mount for cache storage (TrueNAS)
  fileSystems."/mnt/ncps" = {
    device = "truenas.hyades.io:/mnt/HDD/Cache/ncps";
    fsType = "nfs";
    options = [ "defaults" "_netdev" "x-systemd.automount" ];
  };

  # Enable Docker for ncps container
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # ncps container (same configuration as origin)
  virtualisation.oci-containers = {
    backend = "docker";
    containers.ncps = {
      image = "kalbasit/ncps:latest";
      autoStart = true;
      ports = [ "8501:8501" ];
      volumes = [
        "/mnt/ncps:/storage"
      ];
      cmd = [
        "serve"
        "--cache-hostname=ncps.hyades.io"
        "--cache-data-path=/storage"
        "--cache-database-url=sqlite:/storage/var/ncps/db/db.sqlite"
        "--upstream-cache=https://cache.nixos.org"
        "--upstream-cache=https://nix-community.cachix.org"
        "--upstream-public-key=cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "--upstream-public-key=nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };

  # Ensure Docker waits for NFS mount
  systemd.services.docker-ncps = {
    after = [ "mnt-ncps.mount" ];
    requires = [ "mnt-ncps.mount" ];
  };

  # Open firewall for ncps cache
  networking.firewall.allowedTCPPorts = [ 8501 ];

  # Disable NetworkManager (use systemd-networkd)
  networking.networkmanager.enable = lib.mkForce false;
}
