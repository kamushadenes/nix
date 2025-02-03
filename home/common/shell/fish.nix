{
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

          rga-fzf = {
            body = ''
              set RG_PREFIX 'rga --files-with-matches'
              if test (count $argv) -gt 1
                  set RG_PREFIX "$RG_PREFIX $argv[1..-2]"
              end
              set -l file $file
              set file (
                  FZF_DEFAULT_COMMAND="$RG_PREFIX '$argv[-1]'" \
                  fzf --sort \
                      --preview='test ! -z {} && \
                          rga --pretty --context 5 {q} {}' \
                      --phony -q "$argv[-1]" \
                      --bind "change:reload:$RG_PREFIX {q}" \
                      --preview-window='50%:wrap'
              ) && \
              echo "opening $file" && \
              open "$file"
            '';
          };
        }

        (lib.mkIf pkgs.stdenv.isDarwin {
          flushdns = {
            body = "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder";
          };
        })

        (lib.mkIf config.programs.bat.enable {
          help = {
            body = ''"$argv" --help 2>&1 | bat --plain --language=help'';
          };
        })

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
          set -U __done_notification_command "echo \"\$message\" | ${lib.getExe' pkgs.terminal-notifier "terminal-notifier"} -title \"\$title\" -sender \"\$__done_initial_window_id\" -sound default"
        '')

        # Common
        ''
          # Increase escape-period tolerance
          set -g fish_escape_delay_ms 300
        ''

        (lib.mkIf config.programs.yazi.enable ''
          if test $fish_key_bindings = fish_default_key_bindings
              bind \cf yazi
          else
              bind -M insert \cf yazi
          end
        '')

        ''
          fish_add_path -a '${config.home.homeDirectory}/.cargo/bin'
          fish_add_path -a '${config.home.homeDirectory}/.config/emacs/bin'
          fish_add_path -a '${config.home.homeDirectory}/.krew/bin'
          fish_add_path -a '${config.home.homeDirectory}/.config/composer/vendor/bin'
          fish_add_path -a '${config.home.homeDirectory}/.orbstack/bin'

          # Move Nix paths back to the front
          ${helpers.fishProfilesPath};

          # Global Variables
          ${helpers.globalVariables.fishShell}
        ''

        ''
          # SSH Keys
          ${lib.concatMapStringsSep "\n" (key: "test -f ${key}; and ssh-add -q ${key}") sshKeys}
        ''

        # Cache navi init
        (lib.mkIf (
          config.programs.navi.enable && !config.programs.navi.enableFishIntegration
        ) "_evalcache ${lib.getExe pkgs.navi} widget fish")

        # Cache ghostty init
        ''
          # Set GHOSTTY_RESOURCES_DIR if not set
          if test -z "$GHOSTTY_RESOURCES_DIR"
              set -x GHOSTTY_RESOURCES_DIR "/Applications/Ghostty.app/Contents/Resources/ghostty"
          end

          _evalcache cat "$GHOSTTY_RESOURCES_DIR"/shell-integration/fish/vendor_conf.d/ghostty-shell-integration.fish
        ''
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

      shellAliases = lib.mkMerge [
        {
          rebuild =
            if pkgs.stdenv.isDarwin then
              ''nix shell github:viperML/nh --command nh darwin switch -H (hostname -s | sed s"/.local//g")'' # TODO: fix this when 4.0.0 gets merged in nixpkgs
            else
              ''nh os switch -H (hostname -s | sed s"/.local//g")'';

          unlock-gpg = "rm -f ~/.gnupg/public-keys.d/pubring.db.lock";
          renice-baldur = "sudo renice -n -20 -p $(pgrep -f Baldur)";
        }

        (lib.mkIf config.programs.bat.enable {
          cat = "bat -p";
          man = "batman";
        })
        (lib.mkIf config.programs.broot.enable { tree = "broot"; })
        (lib.mkIf config.programs.eza.enable { ls = "eza --icons -F -H --group-directories-first --git"; })
        #(lib.mkIf config.programs.kitty.enable {
        #  ssh = "kitten ssh";
        #  sudo = ''sudo TERMINFO="$TERMINFO"'';
        #})
      ];
    };
  };
}
