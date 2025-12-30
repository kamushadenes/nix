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

  home.packages = with pkgs; [
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
        {
          mkcd = {
            body = "mkdir -p $argv and cd $argv";
          };

          fish_greeting = {
            body = "";
          };

          rebuild = {
            description = "Rebuild nix configuration (decrypts cache key if needed)";
            body =
              let
                cacheKeyPath = "$HOME/.config/nix/config/private/cache-priv-key.pem";
                cacheKeyAgePath = "$HOME/.config/nix/config/private/cache-priv-key.pem.age";
                ageIdentity = "$HOME/.age/age.pem";
                nhCommand =
                  if pkgs.stdenv.isDarwin then
                    ''nh darwin switch --impure -H (hostname -s | sed 's/.local//g')''
                  else
                    ''nh os switch --impure -H (hostname -s | sed 's/.local//g')'';
              in
              ''
                # Decrypt cache signing key if needed
                if test -f ${cacheKeyAgePath}; and not test -f ${cacheKeyPath}
                    echo "Decrypting cache signing key..."
                    if test -f ${ageIdentity}
                        ${pkgs.age}/bin/age -d -i ${ageIdentity} ${cacheKeyAgePath} > ${cacheKeyPath}
                        if test $status -ne 0
                            echo "Failed to decrypt cache key"
                            return 1
                        end
                        chmod 600 ${cacheKeyPath}
                    else
                        echo "Warning: Age identity not found at ${ageIdentity}, skipping cache key decryption"
                    end
                end

                # Run the rebuild
                ${nhCommand}
              '';
          };

          c = {
            description = "Start Claude Code inside tmux";
            body = ''
              if set -q TMUX
                  # Already in tmux, just run claude
                  claude $argv
              else
                  # Generate unique session name: claude-<folder>-<timestamp>
                  set -l folder_name (basename (pwd) | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/-$//')
                  set -l timestamp (date +%s)
                  set -l session_name "claude-$folder_name-$timestamp"

                  # Start tmux and run claude inside it
                  tmux new-session -s "$session_name" "claude $argv; exec fish"
              end
            '';
          };

          add_go_build_tags = {
            description = "Adds a custom Go build constraint to the beginning of .go files recursively.";
            body = ''
              if test -z "$argv[1]"
                  echo "Usage: add_go_build_tags '<BUILD_CONSTRAINT_STRING>'"
                  echo "Example: add_go_build_tags 'customtag || (another && !ignorethis)'"
                  echo "Error: BUILD_CONSTRAINT_STRING argument is missing."
                  return 1
              end

              set -l constraint_string "$argv[1]"

              # The Go compiler will ultimately validate the syntax of the constraint_string.
              # We'll proceed assuming the user provides a valid or intended string.

              set -l new_build_directive "//go:build $constraint_string"

              # Find all .go files recursively from the current directory.
              for go_file in (find . -type f -name "*.go")
                  # Read the first line of the current Go file
                  set -l first_line ""
                  if test -s "$go_file" # Check if file is not empty
                      set first_line (head -n 1 "$go_file")
                  end

                  if test "$first_line" = "$new_build_directive"
                      echo "Skipping (already has directive): $go_file"
                      continue
                  end

                  echo "Processing: $go_file"

                  # Create a temporary file to hold the new content
                  set -l temp_file (mktemp --tmpdir go_build_update.XXXXXX)
                  if test $status -ne 0 -o ! -f "$temp_file"
                      echo "Error: Could not create temporary file for $go_file."
                      if test -f "$temp_file"; rm -f "$temp_file"; end # Attempt cleanup
                      continue
                  end

                  # Write the new build directive, then a blank line, then the original file content.
                  # The blank line after the '//go:build' directive is crucial for Go's syntax.
                  echo "$new_build_directive" > "$temp_file"
                  echo "" >> "$temp_file" # Blank line
                  cat "$go_file" >> "$temp_file"
                  
                  if test $status -ne 0 # Check status of cat or echo redirection
                      echo "Error: Failed to prepare new content for $go_file."
                      rm -f "$temp_file" # Clean up the temporary file
                      continue
                  end
                  
                  # Replace the original file with the temporary file.
                  if mv "$temp_file" "$go_file"
                      # Successfully moved
                  else
                      echo "Error: Could not move temporary file to replace $go_file."
                      # If mv failed, the temp_file might still exist.
                      rm -f "$temp_file" # Try to clean it up.
                  end
              end

              echo "Finished processing Go files."
            '';
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
        #done
        safe-rm
        puffer-fish
        autopair
        fish-async-prompt
        evalcache
        fish_ssh_agent
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
          fish_add_path -a '${config.home.homeDirectory}/go/bin'

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
          unlock-gpg = "rm -f ~/.gnupg/public-keys.d/pubring.db.lock";
          renice-baldur = "sudo renice -n -20 -p $(pgrep -f Baldur)";
        }

        (lib.mkIf config.programs.bat.enable {
          cat = "bat -p";
          man = "batman";
        })
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
