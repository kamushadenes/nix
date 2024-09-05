{
  pkgs,
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
          "Run garbage collection on Nix store" =
            if pkgs.stdenv.isDarwin then
              "${lib.getExe' pkg "nh_darwin"} clean all"
            else
              "${lib.getExe' pkg "nh"} clean all";
        };
    };
  };
}
