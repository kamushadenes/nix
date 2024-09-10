{
  pkgs,
  packages,
  inputs,
  ...
}:
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
      inputs.apple-fonts.packages.${pkgs.system}.sf-pro
      inputs.apple-fonts.packages.${pkgs.system}.sf-mono-nerd
    ];
  };
}
