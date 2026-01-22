# Minimal role system configuration
# Provides default SSH access for kamushadenes and root
# Used for service containers that don't have dedicated private configs
{ config, lib, pkgs, ... }:

let
  authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGqdVyJjYEVc0TfIAEa0OBtqSJJ6bVH1MQcuFnSG0ePp henrique.goncalves@henrique.goncalves";
in
{
  # SSH authorized keys for kamushadenes
  users.users.kamushadenes.openssh.authorizedKeys.keys = [ authorizedKey ];

  # SSH authorized keys for root (for remote deployment)
  users.users.root.openssh.authorizedKeys.keys = [ authorizedKey ];

  # Allow root login for minimal role (needed for remote deployment)
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";
}
