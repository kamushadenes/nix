{ pkgs, ... }:
{
  programs.go = {
    enable = true;
  };

  home.packages = with pkgs; [
    cobra-cli
    gopls
    golangci-lint
    govulncheck
  ];
}
