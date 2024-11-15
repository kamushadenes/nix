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
    httpie
    hugo
    stuntman
    neofetch
    parallel-full
    ripgrep-all
    pkgs-unstable.fabric-ai
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
      commands =
        let
          pkg = osConfig.programs.nh.package;
        in
        {
          "Nix store garbage collection" =
            if pkgs.stdenv.isDarwin then
              "${lib.getExe' pkg "nh_darwin"} clean all"
            else
              "${lib.getExe' pkg "nh"} clean all";
        };
    };
  };
}
