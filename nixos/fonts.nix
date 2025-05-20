{ pkgs, ... }:
{
  # Fonts
  fonts = {
    packages = with pkgs; [
      nerd-fonts.fira-mono
      nerd-fonts.monaspace
      nerd-fonts.symbols-only
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
