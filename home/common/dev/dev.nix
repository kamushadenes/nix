{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    act
    protobuf
    wakatime
  ];
}
