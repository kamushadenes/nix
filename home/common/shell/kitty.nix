{
  inputs,
  config,
  pkgs,
  lib,
  osConfig,
  ...
}:
{
  programs = {
    kitty = {
      enable = true;

      darwinLaunchOptions = [
        "--single-instance"
        "--listen-on=unix:/tmp/kitty.sock"
      ];

      font = {
        name = "MonaspiceNe Nerd Font Mono";
        size = 14;
      };

      shellIntegration = {
        enableBashIntegration = config.programs.bash.enable;
        enableZshIntegration = config.programs.zsh.enable;
        enableFishIntegration = config.programs.fish.enable;
      };

      theme = "Catppuccin-Macchiato";

      settings = {
        update_check_interval = 0;

        term = "xterm-256color";
        allow_hyperklinks = "yes";
        editor = "nvim";

        tab_bar_style = "powerline";
        tab_powerline_style = "slanted";
        tab_bar_min_tabs = 0;

        window_margin_width = 10;
        window_padding_width = 10;

        background_tint = "0.97";
        background_tint_gaps = "-10.0";

        window_resize_step_cells = 2;
        window_resize_step_lines = 2;

        initial_window_width = 640;
        initial_window_height = 400;

        draw_minimal_borders = "yes";

        inactive_text_alpha = "0.7";
        hide_window_decorations = "no";

        # MacOS
        macos_option_as_alt = "yes";
        macos_titlebar_color = "background";

        active_border_color = "none";

        # default layout is vertical splits only
        enabled_layouts = "splits";
        enable_audio_bell = "no";

        # Performance
        input_delay = 0;
        repaint_delay = 2;
        sync_to_monitor = "no";
        wayland_enable_ime = "no";
      };

      keybindings = {
        "cmd+k" = "combine : clear_terminal scrollback active : send_text normal,application \x0c";
        "alt+left" = "send_text all \x1b\x62";
        "alt+right" = "send_text all \x1b\x66";
        "cmd+left" = "send_text all \x01";
        "cmd+right" = "send_text all \x05";
        "cmd+1" = "goto_tab 1";
        "cmd+2" = "goto_tab 2";
        "cmd+3" = "goto_tab 3";
        "cmd+4" = "goto_tab 4";
        "cmd+5" = "goto_tab 5";
        "cmd+6" = "goto_tab 6";
        "cmd+7" = "goto_tab 7";
        "cmd+8" = "goto_tab 8";
        "cmd+9" = "goto_tab 9";
        "cmd+equal" = "change_font_size all +2.0";
        "cmd+minus" = "change_font_size all -2.0";
        "cmd+0" = "change_font_size all 0";
        "cmd+c" = "copy_to_clipboard";
        "cmd+v" = "paste_from_clipboard";
        "alt+1" = "goto_tab 1";
        "alt+2" = "goto_tab 2";
        "alt+3" = "goto_tab 3";
        "alt+4" = "goto_tab 4";
        "alt+5" = "goto_tab 5";
        "alt+6" = "goto_tab 6";
        "alt+7" = "goto_tab 7";
        "alt+8" = "goto_tab 8";
        "alt+9" = "goto_tab 9";
        "alt+0" = "goto_tab 0";
        "cmd+t" = "new_tab";
        "cmd+]" = "next_window";
        "cmd+[" = "previous_window";
        "cmd+w" = "close_window";
        "cmd+shift+n" = "new_os_window";
        "cmd+d" = "launch - location=hsplit - cwd=current";
        "cmd+shift+d" = "launch - location=vsplit - cwd=current";
      };
    };
  };
}
