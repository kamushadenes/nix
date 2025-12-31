{
  config,
  pkgs,
  helpers,
  ...
}:
{

  programs = {
    ghostty = {
      enable = false; # Broken
      package = pkgs.ghostty;

      installBatSyntax = config.programs.bat.enable;
      installVimSyntax = true;
    } // helpers.shellIntegrations;
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

      theme = "${helpers.theme.variants.hyphen}"

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

      # Shift+Enter binding to add a new line in claude-code
      keybind = shift+enter=text:\x1b\r

      # Split bindings (mirror tmux: cmd instead of ctrl+space)
      keybind = super+shift+backslash=new_split:right
      keybind = super+minus=new_split:down

      # Arrow-based navigation (cmd + arrow)
      keybind = super+left=goto_split:left
      keybind = super+right=goto_split:right
      keybind = super+up=goto_split:top
      keybind = super+down=goto_split:bottom

      # Arrow-based splits (cmd + shift + arrow = split in that direction)
      keybind = super+shift+left=new_split:left
      keybind = super+shift+right=new_split:right
      keybind = super+shift+up=new_split:up
      keybind = super+shift+down=new_split:down

      # Pane navigation (cmd+hjkl like tmux prefix+hjkl)
      keybind = super+h=goto_split:left
      keybind = super+j=goto_split:bottom
      keybind = super+k=goto_split:top
      keybind = super+l=goto_split:right

      # Pane resizing (cmd+shift+hjkl like tmux prefix+HJKL)
      keybind = super+shift+h=resize_split:left,50
      keybind = super+shift+j=resize_split:down,50
      keybind = super+shift+k=resize_split:up,50
      keybind = super+shift+l=resize_split:right,50

      # New tab (cmd+t like tmux prefix+t)
      keybind = super+t=new_tab

      # Tab navigation (cmd+1-9 like tmux prefix+1-9)
      keybind = super+one=goto_tab:1
      keybind = super+two=goto_tab:2
      keybind = super+three=goto_tab:3
      keybind = super+four=goto_tab:4
      keybind = super+five=goto_tab:5
      keybind = super+six=goto_tab:6
      keybind = super+seven=goto_tab:7
      keybind = super+eight=goto_tab:8
      keybind = super+nine=goto_tab:9

      # Last tab (cmd+tab like tmux prefix+tab)
      keybind = super+tab=last_tab

      # Toggle zoom (like tmux prefix+z)
      keybind = super+z=toggle_split_zoom

      # Equalize splits
      keybind = super+equal=equalize_splits

      # Quick rebuild (cmd+r) - types and executes rebuild command
      keybind = super+r=text:rebuild\r
    '';
  };
}
