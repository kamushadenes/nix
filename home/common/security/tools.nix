{
  pkgs,
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
  ];
}
