{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    black
    python312Full
  ];
}
