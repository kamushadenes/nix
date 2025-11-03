{ pkgs, ... }:
{
  home.packages = with pkgs; [
    bun
    nodejs
    typescript
    yarn-berry
  ];
}
