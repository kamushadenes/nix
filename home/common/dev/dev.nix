{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    act
    parca
    protobuf
    wakatime
  ];
}
