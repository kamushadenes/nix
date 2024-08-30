{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    act
    protobuf
    wakatime
  ];

  programs.mise = {
    enable = true;
    enableBashIntegration = config.programs.bash.enable;
    enableZshIntegration = config.programs.zsh.enable;
    enableFishIntegration = config.programs.fish.enable;

    globalConfig = {
      tools = {
        node = [ "lts" ];
        python = [ "3.12" ];
        usage = [ "0.3.1" ];
      };
    };

    settings = {
      verbose = false;
      experimental = false;
    };
  };
}
