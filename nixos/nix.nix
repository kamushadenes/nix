{ config, pkgs, ... }:

{
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep-since 4d --keep 3";
    };
    flake = "${config.users.users.kamushadenes.home}/.config/nix/config/?submodules=1";
  };

  documentation = {
    enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = false;
  };
}
