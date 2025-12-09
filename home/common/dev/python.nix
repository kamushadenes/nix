{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    black
    python312
    python312Packages.tkinter
  ];
}
