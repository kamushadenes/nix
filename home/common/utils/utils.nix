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
          "cargo"
          "containers"
          "emacs"
          "flutter"
          "gcloud"
          "node"
          "rustup"
          "vim"
        ];
        cleanup = true;
      };
      commands = {
        "Run garbage collection on Nix store" = "nh clean all";
      };
    };
  };
}
