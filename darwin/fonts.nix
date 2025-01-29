{ pkgs, ... }:
{
  # Fonts
  fonts = {
    packages = with pkgs; [
      (nerdfonts.override {
        fonts = [
          "FiraCode"
          "Monaspace"
          "NerdFontsSymbolsOnly"
        ];
      })
      noto-fonts
      noto-fonts-cjk-sans
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
