{
  config,
  pkgs,
  ...
}:
{

  programs = {
    ghostty = {
      enable = false; # Broken
      package = pkgs.ghostty;

      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;
      enableFishIntegration = config.programs.fish.enable;

      installBatSyntax = config.programs.bat.enable;
      installVimSyntax = true;
    };
  };

  xdg.configFile."ghostty/config" = {
    text = ''
      font-family = "Monaspace Neon Var"
      font-size = 14
      font-thicken = true

      font-style = Medium
      font-style-bold = Bold
      font-style-italic = Medium Italic
      font-style-bold-italic = Bold Italic

      font-feature = "+calt"
      font-feature = "+liga"
      font-feature = "+ss01"
      font-feature = "+ss02"
      font-feature = "+ss03"
      font-feature = "+ss04"
      font-feature = "+ss05"
      font-feature = "+ss06"
      font-feature = "+ss07"
      font-feature = "+ss08"
      font-feature = "+ss09"

      theme = "catppuccin-macchiato"

      minimum-contrast = 1.05

      window-padding-x = 20
      window-padding-y = 20
      #window-decoration = false

      font-codepoint-map = "U+F102,U+F116-U+F118,U+F12F,U+F13E,U+F1AF,U+F1BF,U+F1CF,U+F1FF,U+F20F,U+F21F-U+F220,U+F22E-U+F22F,U+F23F,U+F24F,U+F25F=nonicons"
      font-codepoint-map = "U+e000-U+e00a,U+ea60-U+ebeb,U+e0a0-U+e0c8,U+e0ca,U+e0cc-U+e0d7,U+e200-U+e2a9,U+e300-U+e3e3,U+e5fa-U+e6b1,U+e700-U+e7c5,U+ed00-U+efc1,U+f000-U+f2ff,U+f000-U+f2e0,U+f300-U+f372,U+f400-U+f533,U+f0001-U+f1af0=Symbols Nerd Font Mono"

      shell-integration = detect
      shell-integration-features = sudo
      shell-integration-features = title
      shell-integration-features = cursor

      desktop-notifications = true

      cursor-click-to-move = true

      auto-update = off
    '';
  };
}
