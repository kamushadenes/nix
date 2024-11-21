{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    black
    python312Full
  ];
}
