{ pkgs, ... }:
{
  home.packages = with pkgs; [
    sqlite
    mycli
    pgcli
  ];
}
