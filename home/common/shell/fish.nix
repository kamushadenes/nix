{
  inputs,
  config,
  pkgs,
  lib,
  osConfig,
  helpers,
  ...
}:
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

      plugins = with pkgs; [
        {
          name = "spark.fish";
          src = fetchFromGitHub {
            owner = "jorgebucaran";
            repo = "spark.fish";
            rev = "90a60573ec8a8ecb741a861e0bfca2362f297e5f";
            hash = "sha256-cRSZeqtXSaEKuHeTSk3Kpmwf98mKJ986x1KSxa/HggU=";
          };
        }
        {
          name = "done";
          src = fetchFromGitHub {
            owner = "franciscolourenco";
            repo = "done";
            rev = "eb32ade85c0f2c68cbfcff3036756bbf27a4f366";
            hash = "sha256-DMIRKRAVOn7YEnuAtz4hIxrU93ULxNoQhW6juxCoh4o=";
          };
        }
        {
          name = "safe-rm";
          src = fetchFromGitHub {
            owner = "fishingline";
            repo = "safe-rm";
            rev = "4c65dc566dd0fd6a9c59e959f1b40ce66cc6bfd3";
            hash = "sha256-BqLfvm4oADP9oPNkOCatyNfZ3RGqAtldiqeeORIo3Bc=";
          };
        }
        {
          name = "puffer-fish";
          src = fetchFromGitHub {
            owner = "nickeb96";
            repo = "puffer-fish";
            rev = "12d062eae0ad24f4ec20593be845ac30cd4b5923";
            hash = "sha256-2niYj0NLfmVIQguuGTA7RrPIcorJEPkxhH6Dhcy+6Bk=";
          };
        }
        {
          name = "autopair.fish";
          src = fetchFromGitHub {
            owner = "jorgebucaran";
            repo = "autopair.fish";
            rev = "4d1752ff5b39819ab58d7337c69220342e9de0e2";
            hash = "sha256-qt3t1iKRRNuiLWiVoiAYOu+9E7jsyECyIqZJ/oRIT1A=";
          };
        }
        {
          name = "fish-async-prompt";
          src = fetchFromGitHub {
            owner = "acomagu";
            repo = "fish-async-prompt";
            rev = "316aa03c875b58e7c7f7d3bc9a78175aa47dbaa8";
            hash = "sha256-J7y3BjqwuEH4zDQe4cWylLn+Vn2Q5pv0XwOSPwhw/Z0=";
          };
        }
        {
          name = "fish-evalcache";
          src = fetchFromGitHub {
            owner = "kamushadenes";
            repo = "fish-evalcache";
            rev = "54767fec7a928d747b5211131ed4d193d2a7e979";
            hash = "sha256-G5zVzmAKWgZgJns3d4w5rC7/6uTwwfaYPwZhV0+QNO4=";
          };
        }
      ];

      shellInit = lib.mkMerge [
        # Darwin

        # Cache homebrew init
        (lib.mkIf (pkgs.stdenv.isDarwin) "_evalcache /opt/homebrew/bin/brew shellenv")

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

          # SSH Keys
          ssh-add -q /Users/kamushadenes/.ssh/keys/id_ed25519
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
