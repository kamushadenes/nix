{
  pkgs,
  pkgs-unstable,
  ...
}:
{
  home.packages = with pkgs; [
    _1password-cli
    nmap
    nuclei
    nuclei-templates
    rustscan
    tfsec
    pkgs-unstable.fleetctl
    pkgs-unstable.age
  ];
}
