{ pkgs, packages, ... }:
{
  # Fonts
  fonts = {
    packages = with pkgs; [
      nerdfonts
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      font-awesome
      sketchybar-app-font
      monaspace
    ];
  };

  homebrew.casks = [
    "font-ligature-symbols"
    "font-sf-pro"
    "font-sf-mono"
    "font-sf-mono-for-powerline"
  ];
}
