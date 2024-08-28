{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    autoconf
    automake
    cmake
    gnumake
    gnum4
  ];
}
