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
      source-han-sans
      source-han-sans-japanese
      source-han-serif-japanese
      monaspace
    ];
  };
}
