{ pkgs, ... }:
{
  home.packages = with pkgs; [
    infracost
    packer
    terraform
  ];
}
