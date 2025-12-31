# Cross-platform shell configuration
# Shared between Darwin and NixOS
{ pkgs, ... }:
{
  programs = {
    bash = {
      enable = true;
    };

    fish = {
      enable = true;
    };
  };

  environment.shells = with pkgs; [
    bash
    fish
  ];
}
