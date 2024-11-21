{ pkgs, ... }:
{
  home.packages = with pkgs; [
    autoconf
    automake
    cmake
    gnumake
    gnum4
  ];
}
