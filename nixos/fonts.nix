{ pkgs, packages, ... }:
{
  # Fonts
  fonts = {
    packages = with pkgs; [
      monaspace
      (nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
      packages.monaspice
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      font-awesome
      source-han-sans
      source-han-sans-japanese
      source-han-serif-japanese
    ];
  };
}
