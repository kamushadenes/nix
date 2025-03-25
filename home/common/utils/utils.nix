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
    glow
    httpie
    hugo
    stuntman
    neofetch
    parallel-full
    ripgrep-all
    pkgs-unstable.fabric-ai
    poppler_utils
    tesseract
    qpdf
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
