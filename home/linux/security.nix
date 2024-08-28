{
  pkgs,
  lib,
  config,
  ...
}:
{
  home.packages = with pkgs; lib.optionals pkgs.stdenv.isLinux [ aircrack-ng ];
}
