{ pkgs, helpers, ... }:
{
  systemd = {
    user = {
      enable = pkgs.stdenv.isLinux;
      sessionVariables = helpers.globalVariables.base;
    };
  };
}
