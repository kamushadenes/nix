{ pkgs, globalVariables, ... }:
{
  systemd = {
    user = {
      enable = pkgs.stdenv.isLinux;
      sessionVariables = globalVariables.base;
    };
  };
}
