{ pkgs, pkgs-unstable, ... }:
{
  programs.go = {
    enable = true;
  };

  home.packages = with pkgs; [
    cobra-cli
    pkgs-unstable.gopls
    pkgs-unstable.golangci-lint
    pkgs-unstable.govulncheck
    pkgs-unstable.gotestsum
    pkgs-unstable.go-outline
  ];
}
