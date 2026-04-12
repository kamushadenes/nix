{
  config,
  pkgs,
  lib,
  osConfig,
  helpers,
  fishPlugins,
  shellCommon,
  ...
}:
{
  home.sessionVariables = helpers.globalVariables.base;

  home.packages =
    with pkgs;
    [
      # Claude Code workspace manager - standalone bash script with multi-account support
      (writeScriptBin "c" shellCommon.standaloneScripts.c)

      # OpenCode wrapper - launches opencode via c --opencode
      (writeScriptBin "co" shellCommon.standaloneScripts.co)

      # Rebuild script - unified bash script for local and remote deployments
      (writeScriptBin "rebuild" shellCommon.standaloneScripts.rebuild)

      # LXC machine registration script - adds machines to lxc-management secrets
      (writeScriptBin "lxc-add-machine" shellCommon.standaloneScripts.lxc-add-machine)
    ]
    ++ lib.optionals stdenv.isDarwin [
      terminal-notifier
      (writeScriptBin "sbrew" ''
        #!/usr/bin/env bash
        cd "${osConfig.homebrew.brewPrefix}"
        sudo -Hu "${osConfig.homebrew.user}" "${osConfig.homebrew.brewPrefix}/brew" "$@"
      '')
    ];

  programs = {
    fish = {
      enable = true;
      functions = lib.mkMerge [
        shellCommon.fish.functions

        (lib.mkIf config.programs.starship.enable {
          starship_transient_prompt_func.body = "starship module character";

          starship_transient_rprompt_func.body = "";

          fish_right_prompt_loading_indicator = {
            body = ''
              echo -n "$last_prompt" | sed -r 's/\x1B\[[0-9;]*[JKmsu]//g' | read -zl uncolored_last_prompt
              echo -n (set_color brblack)"$uncolored_last_prompt"(set_color normal)
            '';
            argumentNames = "last_prompt";
          };
        })
      ];

      plugins = with fishPlugins; [
        spark
        safe-rm
        puffer-fish
        autopair
        fish-async-prompt
        evalcache
        fish_ssh_agent
      ];

      shellInit = lib.mkMerge [
        # Cache homebrew init
        shellCommon.fish.homebrewInit

        # Common
        ''
          # Increase escape-period tolerance
          set -g fish_escape_delay_ms 300
        ''

        (lib.mkIf config.programs.yazi.enable ''
          if test "$fish_key_bindings" = fish_default_key_bindings
              bind \cf yazi
          else
              bind -M insert \cf yazi
          end
        '')

        # PATH setup
        ''
          ${shellCommon.fish.pathSetup}

          # Move Nix paths back to the front
          ${helpers.fishProfilesPath};

          # Global Variables
          ${helpers.globalVariables.fishShell}
        ''

        # OTEL secrets (endpoint + headers from agenix)
        ''
          if test -f ~/.config/opencode/secrets/otel-endpoint
              set -x OPENCODE_OTLP_ENDPOINT (cat ~/.config/opencode/secrets/otel-endpoint)
              set -x OTEL_EXPORTER_OTLP_ENDPOINT (cat ~/.config/opencode/secrets/otel-endpoint)
          end
          if test -f ~/.config/opencode/secrets/otel-headers
              set -x OPENCODE_OTLP_HEADERS (cat ~/.config/opencode/secrets/otel-headers)
              set -x OTEL_EXPORTER_OTLP_HEADERS (cat ~/.config/opencode/secrets/otel-headers)
          end
        ''

        # SSH key loading
        ''
          ${shellCommon.fish.sshKeyLoading}
        ''

        # Worktrunk shell integration (enables wt switch to change directory)
        ''
          if command -q wt
            wt config shell init fish 2>/dev/null | source
          end
        ''

        # Cache navi init
        (lib.mkIf (
          config.programs.navi.enable && !config.programs.navi.enableFishIntegration
        ) "_evalcache ${lib.getExe pkgs.navi} widget fish")

        # Ghostty shell integration
        shellCommon.fish.ghosttyIntegration
      ];

      interactiveShellInit = lib.mkMerge [
        # Cache fzf init
        (lib.mkIf (
          config.programs.fzf.enable && !config.programs.fzf.enableFishIntegration
        ) "_evalcache ${lib.getExe pkgs.fzf} --fish")

        # Cache atuin init
        (lib.mkIf (config.programs.atuin.enable && !config.programs.atuin.enableFishIntegration) ''
          _evalcache ${lib.getExe pkgs.atuin} init fish ${lib.concatStringsSep " " config.programs.atuin.flags}
        '')
      ];

      shellInitLast = lib.mkMerge [
        # Fix fish-async-prompt
        (lib.mkIf config.programs.starship.enable (
          lib.mkMerge [
            "set -x STARSHIP_LOG error"

            (lib.mkIf (!config.programs.starship.enableFishIntegration) (
              lib.mkMerge [
                # Cache starship init
                "_evalcache ${lib.getExe pkgs.starship} init fish"

                (lib.mkIf config.programs.starship.enableTransience "enable_transience")
              ]
            ))

            "set -U async_prompt_functions fish_right_prompt"
          ]
        ))

        # Override fish-async-prompt cleanup to bypass safe-rm.
        # The plugin uses bare `rm` which gets intercepted by safe-rm,
        # moving temp files to trash instead of deleting them on shell exit.
        # Using `command rm` calls the real rm binary directly.
        ''
          function __async_prompt_tmpdir_cleanup --on-event fish_exit
              command rm -rf "$__async_prompt_tmpdir"
          end
        ''
      ];

      loginShellInit = helpers.fishProfilesPath;

      shellAliases = shellCommon.aliases;
    };
  };
}
