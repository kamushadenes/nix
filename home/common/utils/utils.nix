{
  pkgs,
  pkgs-unstable,
  lib,
  osConfig,
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
      commands =
        let
          pkg = osConfig.programs.nh.package;
        in
        {
          "Nix store garbage collection" = "${lib.getExe' pkg "nh"} clean all";
        };
    };
  };
}
