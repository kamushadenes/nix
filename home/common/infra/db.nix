{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    sqlite
    mycli
    mariadb
    postgresql
    pgcli
  ];
}
