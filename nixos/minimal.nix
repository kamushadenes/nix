# Minimal role system configuration
# Provides default SSH access for kamushadenes and root
# Used for service containers that don't have dedicated private configs
{ config, lib, pkgs, ... }:

let
  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBahOBnKD4VKrz8UWky69DY+LXcbcj3/ybO1KFbGaeaE truenas"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGqdVyJjYEVc0TfIAEa0OBtqSJJ6bVH1MQcuFnSG0ePp henrique.goncalves@henrique.goncalves"
  ];
in
{
  # Enable SSH daemon with persistent host keys
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = lib.mkForce "prohibit-password";
    # Use persistent host keys (survives ephemeral root rebuilds)
    hostKeys = [
      { path = "/nix/persist/etc/ssh/ssh_host_ed25519_key"; type = "ed25519"; }
      { path = "/nix/persist/etc/ssh/ssh_host_rsa_key"; type = "rsa"; bits = 4096; }
    ];
  };

  # SSH authorized keys for kamushadenes
  users.users.kamushadenes.openssh.authorizedKeys.keys = authorizedKeys;

  # SSH authorized keys for root (for remote deployment)
  users.users.root.openssh.authorizedKeys.keys = authorizedKeys;
}
