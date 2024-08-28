{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    infracost
    terraform
    packer
    pulumi
  ];
}
