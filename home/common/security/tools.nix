{
  pkgs,
  lib,
  config,
  ...
}:
{
  home.packages = with pkgs; [
    _1password
    nmap
    rustscan
    tfsec
  ];
}
