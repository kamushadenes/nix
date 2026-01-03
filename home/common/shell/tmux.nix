{
  config,
  pkgs,
  lib,
  ...
}:
let
  resourcesDir = ./resources;
  sessionDurationScript = pkgs.writeShellScript "session-duration" ''
    # Get session_created timestamp from tmux
    created=$(${pkgs.tmux}/bin/tmux display-message -p '#{session_created}' 2>/dev/null)
    if [ -z "$created" ]; then
      printf ' ??h ??m'
      exit 0
    fi
    now=$(${pkgs.coreutils}/bin/date +%s)
    diff=$((now - created))
    hours=$((diff / 3600))
    mins=$(((diff % 3600) / 60))
    printf ' %dh %dm' "$hours" "$mins"
  '';
in
{
  programs.tmux = {
    enable = true;

    # Core settings
    prefix = "C-Space";
    keyMode = "vi";
    mouse = true;
    terminal = "tmux-256color";
    escapeTime = 0;
    historyLimit = 50000;
    baseIndex = 1;
    focusEvents = true;
    disableConfirmationPrompt = true;

    # Plugins
    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      pain-control
      resurrect
      continuum
      catppuccin
    ];

    extraConfig = ''
      # Catppuccin Macchiato configuration
      set -g @catppuccin_flavor "macchiato"
      set -g @catppuccin_window_status_style "rounded"
      set -g @catppuccin_status_background "default"

      # Status bar modules
      set -g status-right-length 100
      set -g status-left-length 100
      set -g status-left ""
      # Session duration calculation via script (queries tmux for session_created)
      set -g status-right "#{E:@catppuccin_status_date_time} #{E:@catppuccin_status_session} "
      set -g @catppuccin_date_time_text "#(${sessionDurationScript})"
      set -g status-interval 5

      # Continuum settings
      set -g @continuum-restore 'on'
      set -g @continuum-save-interval '10'

      # Resurrect settings
      set -g @resurrect-capture-pane-contents 'on'
      set -g @resurrect-strategy-nvim 'session'

      # True color and Unicode support for Ghostty
      set -g default-terminal "tmux-256color"
      set -sa terminal-overrides ",xterm*:Tc"

      # Pane border styling (Catppuccin Macchiato colors)
      set -g pane-border-style "fg=#494d64"
      set -g pane-active-border-style "fg=#8aadf4"

      # Better split bindings (keep current directory)
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"
      bind t new-window -c "#{pane_current_path}"

      # Arrow-based navigation (prefix + arrow)
      bind Left select-pane -L
      bind Right select-pane -R
      bind Up select-pane -U
      bind Down select-pane -D

      # Arrow-based splits (prefix + shift + arrow = split in that direction)
      bind S-Left split-window -hb -c "#{pane_current_path}"
      bind S-Right split-window -h -c "#{pane_current_path}"
      bind S-Up split-window -vb -c "#{pane_current_path}"
      bind S-Down split-window -v -c "#{pane_current_path}"

      # Vi-style pane navigation (with prefix)
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Resize panes with HJKL (with prefix, repeatable)
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # Window navigation (with prefix)
      bind 1 select-window -t 1
      bind 2 select-window -t 2
      bind 3 select-window -t 3
      bind 4 select-window -t 4
      bind 5 select-window -t 5
      bind 6 select-window -t 6
      bind 7 select-window -t 7
      bind 8 select-window -t 8
      bind 9 select-window -t 9

      # Quick window switching (prefix + n/p already work, add Tab)
      bind Tab last-window
      bind Space last-pane

      # Quick reload
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

      # Vi copy mode enhancements
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel
      bind -T copy-mode-vi C-v send-keys -X rectangle-toggle

      # Window naming - keep explicit names, don't auto-rename to command
      set -g automatic-rename off
      set -g renumber-windows on

      # Activity monitoring (visual only, no bell)
      setw -g monitor-activity on
      set -g visual-activity off

      # Better window/pane indices display
      set -g display-panes-time 2000
      set -g display-time 2000
    '';
  };
}
