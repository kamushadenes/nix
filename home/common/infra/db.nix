{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    sqlite
    mycli
    pgcli
  ];
}
