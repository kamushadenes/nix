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
}
