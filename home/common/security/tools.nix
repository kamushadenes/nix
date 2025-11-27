{
  pkgs,
  pkgs-unstable,
  ...
}:
{
  home.packages = with pkgs; [
    age-plugin-yubikey
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
