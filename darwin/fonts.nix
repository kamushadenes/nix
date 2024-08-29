{ pkgs, packages, ... }:
{
  # Fonts
  fonts = {
    packages = with pkgs; [
      monaspace
      nerdfonts
      packages.monaspice
    ];
  };
}
