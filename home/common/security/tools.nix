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
    nuclei
    nuclei-templates
    rustscan
    tfsec
  ];
}
