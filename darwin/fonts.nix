{ pkgs, packages, ... }:
{
  # Fonts
  fonts = {
    packages = with pkgs; [
      monaspace
      (nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
      packages.monaspice
    ];
  };
}
