{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    infracost
    packer
    terraform
  ];
}
