{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    act
    #parca
    protobuf
    svu
    wakatime
    graphqurl
    aider-chat
    just
  ];
}
