{
  pkgs,
  pkgs-unstable,
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
    pkgs-unstable.supabase-cli
    #pkgs-unstable.wrangler
  ];
}
