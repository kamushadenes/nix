{
  inputs,
  config,
  pkgs,
  lib,
  osConfig,
  helpers,
  fishPlugins,
  ...
}:
let
  sshKeys = [ config.age.secrets."id_ed25519.age".path ];
in
{
  home.sessionVariables = helpers.globalVariables.base;

  home.packages = with pkgs; [ terminal-notifier ];

  programs = {
    fish = {
      enable = true;
      functions = lib.mkMerge [
        {
          mkcd = {
            body = "mkdir -p $argv and cd $argv";
          };

          fish_greeting = {
            body = "";
          };

          flushdns = {
            body = "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder";
          };
        }

        (lib.mkIf config.programs.starship.enable {
          starship_transient_prompt_func = {
            body = "starship module character";
          };

          starship_transient_rprompt_func = {
            body = "";
          };

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
        done
        safe-rm
        puffer-fish
        autopair
        fish-async-prompt
        evalcache
      ];

      shellInit = lib.mkMerge [
        # Darwin

        # Cache homebrew init
        (lib.mkIf (pkgs.stdenv.isDarwin) "_evalcache ${osConfig.homebrew.brewPrefix}/brew shellenv")

        # Force the use of terminal-notifier to work around Kitty broken notifications
        (lib.mkIf (pkgs.stdenv.isDarwin && config.programs.kitty.enable) ''
          set -U __done_notification_command "echo \"\$message\" | terminal-notifier -title \"\$title\" -sender \"\$__done_initial_window_id\" -sound default"
        '')

        # Common
        (lib.mkIf config.programs.yazi.enable ''
          if test $fish_key_bindings = fish_default_key_bindings
              bind \cf ya
          else
              bind -M insert \cf ya
          end
        '')

        ''
          fish_add_path -a '${config.home.homeDirectory}/.cargo/bin'
          fish_add_path -a '${config.home.homeDirectory}/.config/emacs/bin'
          fish_add_path -a '${config.home.homeDirectory}/.krew/bin'

          # Move Nix paths back to the front
          ${helpers.fishProfilesPath};

          # Global Variables
          ${helpers.globalVariables.fishShell}

          # Docker host running on a remote machine
          set -x DOCKER_HOST "tcp://10.23.23.204:2375"
        ''

        ''
          # SSH Keys
          ${lib.concatMapStringsSep "\n" (key: "test -f ${key}; and ssh-add -q ${key}") sshKeys}
        ''

        # Cache navi init
        (lib.mkIf (
          config.programs.navi.enable && !config.programs.navi.enableFishIntegration
        ) "_evalcache ${pkgs.navi}/bin/navi widget fish")
      ];

      interactiveShellInit = lib.mkMerge [
        # Cache fzf init
        (lib.mkIf (
          config.programs.fzf.enable && !config.programs.fzf.enableFishIntegration
        ) "_evalcache ${pkgs.fzf}/bin/fzf --fish")

        # Cache atuin init
        (lib.mkIf (config.programs.atuin.enable && !config.programs.atuin.enableFishIntegration) ''
          _evalcache ${pkgs.atuin}/bin/atuin init fish ${lib.concatStringsSep " " config.programs.atuin.flags}
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
                "_evalcache starship init fish"

                (lib.mkIf config.programs.starship.enableTransience "enable_transience")
              ]
            ))

            "set -U async_prompt_functions fish_right_prompt"
          ]
        ))
      ];

      loginShellInit = helpers.fishProfilesPath;

      shellAliases = lib.mkMerge [
        {
          rebuild =
            if osConfig.programs.nh.enable then
              ''nh os switch -H (hostname -s | sed s"/.local//g")''
            else if pkgs.stdenv.isDarwin then
              ''darwin-rebuild switch --flake "${helpers.globalVariables.base.FLAKE}"''
            else
              ''sudo nixos-rebuild switch --flake "${helpers.globalVariables.base.FLAKE}"'';
        }

        (lib.mkIf pkgs.stdenv.isDarwin { nh = "nh_darwin"; })

        (lib.mkIf config.programs.bat.enable { cat = "bat -p"; })
        (lib.mkIf config.programs.broot.enable { tree = "broot"; })
        (lib.mkIf config.programs.eza.enable { ls = "eza --icons -F -H --group-directories-first --git"; })
        (lib.mkIf config.programs.kitty.enable {
          ssh = "kitten ssh";
          sudo = ''sudo TERMINFO="$TERMINFO"'';
        })
      ];
    };
  };
}
