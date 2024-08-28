{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    trash-cli
    asciinema
    httpie
    hugo
    stuntman
    neofetch
  ];

  programs.topgrade = {
    enable = true;
    settings = {
      misc = {
        disable = [
          "flutter"
          "node"
        ];
        cleanup = true;
      };
      commands = {
        "Run garbage collection on Nix store" = "nix-collect-garbage";
      };
    };
  };
}
