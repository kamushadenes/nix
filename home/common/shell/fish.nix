{
  inputs,
  config,
  pkgs,
  lib,
  osConfig,
  globalVariables,
  helpers,
  ...
}:
{
  home.sessionVariables = globalVariables.base;

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
      ];

      shellInit = lib.mkMerge [
        # Darwin
        (lib.mkIf (pkgs.stdenv.isDarwin) ''
          # Setup homebrew
          /opt/homebrew/bin/brew shellenv | source
        '')

        (lib.mkIf config.programs.yazi.enable ''
          if test $fish_key_bindings = fish_default_key_bindings
              bind \cf ya
          else
              bind -M insert \cf ya
          end
        '')

        # Common
        ''
          fish_add_path -a '${config.home.homeDirectory}/.cargo/bin'
          fish_add_path -a '${config.home.homeDirectory}/.config/emacs/bin'
          fish_add_path -a '${config.home.homeDirectory}/.krew/bin'

          # Move Nix paths back to the front
          ${helpers.setProfilesPath};

          ${globalVariables.fishShell}

          # Docker host running on a remote machine
          set -x DOCKER_HOST "tcp://10.23.23.204:2375"

          # SSH Keys
          ssh-add -q /Users/kamushadenes/.ssh/keys/id_ed25519
        ''

        (lib.mkIf config.programs.starship.enable ''
          set -x STARSHIP_LOG error
        '')

        # Force the use of terminal-notifier to work around Kitty broken notifications
        (lib.mkIf (pkgs.stdenv.isDarwin && config.programs.kitty.enable) ''
          set -U __done_notification_command "echo \"\$message\" | terminal-notifier -title \"\$title\" -sender \"\$__done_initial_window_id\" -sound default"
        '')
      ];

      shellInitLast = lib.mkMerge [
        (lib.mkIf config.programs.starship.enable ''
          # Fix fish-async-prompt
          starship init fish | source

          set -U async_prompt_functions fish_right_prompt
        '')
      ];

      loginShellInit = helpers.setProfilesPath;

      shellAliases = lib.mkMerge [
        {
          rebuild =
            if osConfig.programs.nh.enable then
              ''nh os switch -H (hostname -s | sed s"/.local//g")''
            else if pkgs.stdenv.isDarwin then
              ''darwin-rebuild switch --flake "${globalVariables.base.FLAKE}"''
            else
              ''sudo nixos-rebuild switch --flake "${globalVariables.base.FLAKE}"'';
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
