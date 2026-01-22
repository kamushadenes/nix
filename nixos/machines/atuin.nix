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
    database.uri = "sqlite:///var/lib/atuin/atuin.db";
  };
}
