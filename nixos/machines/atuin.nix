# Machine configuration for atuin LXC
# Atuin shell history sync server
{ config, lib, pkgs, ... }:

{
  services.atuin = {
    enable = true;
    host = "0.0.0.0";
    port = 8888;
    openRegistration = false;
    openFirewall = true;
    database = {
      createLocally = false; # We use SQLite, not PostgreSQL
      uri = "sqlite:///var/lib/atuin/atuin.db";
    };
  };

  # Create static user for atuin (DynamicUser doesn't work with bind mounts)
  users.users.atuin = {
    isSystemUser = true;
    group = "atuin";
    home = "/var/lib/atuin";
  };
  users.groups.atuin = { };

  # Override systemd unit to use static user instead of DynamicUser
  # DynamicUser + PrivateMounts + bind mounts = permission issues
  systemd.services.atuin = {
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "atuin";
      Group = "atuin";
      StateDirectory = "atuin";
      StateDirectoryMode = "0700";
    };
  };

  # Use systemd-networkd only (disable NetworkManager from base network.nix)
  networking.networkmanager.enable = lib.mkForce false;
}
