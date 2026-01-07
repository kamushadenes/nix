{
  pkgs,
  pkgs-unstable,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    trash-cli
    asciinema
    gam
    glow
    httpie
    hugo
    stuntman
    pkgs-unstable.neofetch
    parallel-full
    pkgs-unstable.ripgrep-all
    pkgs-unstable.fabric-ai
    poppler-utils
    tesseract
    qpdf
    pkgs-unstable.ncdu
  ];

  programs.topgrade = {
    enable = true;
    settings = {
      misc = {
        disable = [
          "bun"
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
        "Nix store garbage collection" = "${lib.getExe' pkgs.nh "nh"} clean all";
      };
    };
  };
}
