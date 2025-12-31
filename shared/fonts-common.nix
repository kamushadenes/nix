# Cross-platform font definitions
# Returns font package lists for use by darwin/fonts.nix and nixos/fonts.nix
{ pkgs }:
{
  common = with pkgs; [
    nerd-fonts.fira-mono
    nerd-fonts.monaspace
    nerd-fonts.symbols-only
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    font-awesome
    monaspace
  ];

  darwin = with pkgs; [
    sketchybar-app-font
  ];

  nixos = with pkgs; [
    source-han-sans
    source-han-sans-japanese
    source-han-serif-japanese
  ];
}
