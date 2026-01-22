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

  home.packages = with pkgs;
    [
      # Claude Code workspace manager - standalone bash script with multi-account support
      (writeScriptBin "c" shellCommon.standaloneScripts.c)

      # Rebuild script - unified bash script for local and remote deployments
      (writeScriptBin "rebuild" shellCommon.standaloneScripts.rebuild)
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
      ];

      loginShellInit = helpers.fishProfilesPath;

      shellAliases = shellCommon.aliases;
    };
  };
}
