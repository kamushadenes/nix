{
  pkgs,
  lib,
  osConfig,
  helpers,
  ...
}:
let
  bordersBlacklist = [ "iPhone Mirroring" ];
in
{
  home.packages = with pkgs; [ jankyborders ];

  xdg.configFile = lib.mkIf pkgs.stdenv.isDarwin {
    "aerospace/aerospace.toml" = {
      text = lib.strings.concatStringsSep "\n" [
        (helpers.toTOML {
          after-login-command = [ ];
          after-startup-command = [
            ''exec-and-forget ${lib.getExe pkgs.jankyborders} active_color=0xffe1e3e4 inactive_color=0xff494d64 width=3.0 order=a blacklist="${lib.concatStringsSep "," bordersBlacklist}"''
          ];
          # Notify Sketchybar about workspace change
          exec-on-workspace-change = [
            (lib.getExe pkgs.bash)
            "-c"
            "${osConfig.homebrew.brewPrefix}/sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE"
          ];
          start-at-login = true;
          enable-normalization-flatten-containers = true;
          enable-normalization-opposite-orientation-for-nested-containers = true;
          accordion-padding = 30;
          default-root-container-layout = "tiles";
          default-root-container-orientation = "auto";
          key-mapping.preset = "qwerty";
          on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

          gaps = {
            inner.horizontal = 10;
            inner.vertical = 10;
            outer.left = 10;
            outer.bottom = 10;
            outer.top = 53;
            outer.right = 10;
          };

          mode.main.binding = {
            alt-slash = "layout tiles horizontal vertical";
            alt-comma = "layout accordion horizontal vertical";
            alt-j = "focus left";
            alt-k = "focus down";
            alt-i = "focus up";
            alt-l = "focus right";
            alt-shift-j = "move left";
            alt-shift-k = "move down";
            alt-shift-i = "move up";
            alt-shift-l = "move right";
            alt-shift-minus = "resize smart -50";
            alt-shift-equal = "resize smart +50";
            alt-1 = "workspace 1";
            alt-2 = "workspace 2";
            alt-3 = "workspace 3";
            alt-4 = "workspace 4";
            alt-5 = "workspace 5";
            alt-6 = "workspace 6";
            alt-7 = "workspace 7";
            alt-8 = "workspace 8";
            alt-9 = "workspace 9";
            alt-shift-1 = "move-node-to-workspace 1";
            alt-shift-2 = "move-node-to-workspace 2";
            alt-shift-3 = "move-node-to-workspace 3";
            alt-shift-4 = "move-node-to-workspace 4";
            alt-shift-5 = "move-node-to-workspace 5";
            alt-shift-6 = "move-node-to-workspace 6";
            alt-shift-7 = "move-node-to-workspace 7";
            alt-shift-8 = "move-node-to-workspace 8";
            alt-shift-9 = "move-node-to-workspace 9";
            alt-tab = "workspace-back-and-forth";
            alt-shift-tab = "move-workspace-to-monitor --wrap-around next";
            alt-shift-semicolon = "mode service";
          };

          mode.service.binding = {
            esc = [
              "reload-config"
              "mode main"
            ];
            r = [
              "flatten-workspace-tree"
              "mode main"
            ]; # reset layout
            f = [
              "layout floating tiling"
              "mode main"
            ]; # Toggle between floating and tiling layout
            backspace = [
              "close-all-windows-but-current"
              "mode main"
            ];
            alt-shift-h = [
              "join-with left"
              "mode main"
            ];
            alt-shift-j = [
              "join-with down"
              "mode main"
            ];
            alt-shift-k = [
              "join-with up"
              "mode main"
            ];
            alt-shift-l = [
              "join-with right"
              "mode main"
            ];
          };
        })
        ''
          # Fix Ghostty
          [[on-window-detected]]
          if.app-id="com.mitchellh.ghostty"
          run = [
            # FIX: this is a workaround for https://github.com/nikitabobko/AeroSpace/issues/68
            # this was also observed in:
            # - https://github.com/ghostty-org/ghostty/issues/1840
            # - https://github.com/ghostty-org/ghostty/issues/2006
            "layout floating",
            "move-node-to-workspace 1",
          ]
        ''
        ''
          # Mail keeps freezing
          [[on-window-detected]]
          if.app-id="com.apple.mail"
          run = [
            "layout floating",
          ]
        ''
        ''
          [[on-window-detected]]
          if.app-id="com.tinyspeck.slackmacgap"
          run = [
            "move-node-to-workspace 2",
          ]
        ''
        ''
          [[on-window-detected]]
          if.app-id="net.whatsapp.WhatsApp"
          run = [
            "move-node-to-workspace 2",
          ]
        ''
        ''
          [[on-window-detected]]
          if.app-id="com.neovide.neovide"
          run = [
            "move-node-to-workspace 1",
          ]
        ''
        ''
          # Fix Orion
          [[on-window-detected]]
          if.window-title-regex-substring = "Orion Preview"
          run = [
            "move-node-to-workspace 1",
          ]
        ''
      ];
    };
  };
}
